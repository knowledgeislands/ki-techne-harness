from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


CONTROLLER_PATH = Path(__file__).parents[1] / "src" / "controller.py"
SPEC = importlib.util.spec_from_file_location("techne_controller", CONTROLLER_PATH)
assert SPEC and SPEC.loader
controller_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = controller_module
SPEC.loader.exec_module(controller_module)


class FakeTelegram:
    def __init__(self) -> None:
        self.messages: list[tuple[int, str]] = []

    def send_message(self, chat_id: int, text: str) -> None:
        self.messages.append((chat_id, text))


class FakeKubernetes:
    def __init__(self, existing: bool = False, failed: bool = False) -> None:
        self.jobs: dict[str, dict] = {}
        self.creates = 0
        self.deletes = 0
        self.failed = failed
        if existing:
            self.jobs["techne-local-42"] = self._job("techne-local-42")

    def _job(self, name: str) -> dict:
        condition = "Failed" if self.failed else "Complete"
        update_id = name.rsplit("-", 1)[-1]
        return {
            "metadata": {
                "name": name,
                "annotations": {
                    "techne.knowledgeislands.dev/execution-id": f"telegram:{update_id}:local"
                },
            },
            "status": {"conditions": [{"type": condition, "status": "True"}]},
        }

    def get_job(self, name: str) -> dict | None:
        return self.jobs.get(name)

    def create_job(self, job: dict) -> dict:
        self.creates += 1
        stored = self._job(job["metadata"]["name"])
        self.jobs[job["metadata"]["name"]] = stored
        return stored

    def list_jobs(self) -> list[dict]:
        return list(self.jobs.values())

    def delete_job(self, name: str) -> bool:
        if name not in self.jobs:
            return False
        self.deletes += 1
        del self.jobs[name]
        return True

    def pod_name(self, job_name: str) -> str:
        return f"{job_name}-pod"

    def pod_logs(self, pod_name: str) -> str:
        return json.dumps({"pod": pod_name, "outcome": "failed" if self.failed else "completed"})


def update(update_id: int = 42, text: str = "/run local", user_id: int = 7, chat_id: int = 9, date: int = 101) -> dict:
    return {
        "update_id": update_id,
        "message": {
            "date": date,
            "text": text,
            "from": {"id": user_id},
            "chat": {"id": chat_id, "type": "private"},
        },
    }


class ControllerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.telegram = FakeTelegram()
        self.target = controller_module.Target("local", "https://kubernetes.default.svc", "techne-execution", "/ca", "/token")

    def make_controller(self, kube: FakeKubernetes, start_worker=None) -> object:
        return controller_module.Controller(
            telegram=self.telegram,
            targets={"local": self.target},
            operator_user_id=7,
            operator_chat_id=9,
            initial_offset=40,
            kube_factory=lambda target: kube,
            sleep=lambda seconds: None,
            monotonic=lambda: 0,
            start_worker=start_worker or (lambda callback: callback()),
        )

    def test_dispatch_creates_one_deterministic_job(self) -> None:
        kube = FakeKubernetes()
        next_offset = self.make_controller(kube).handle_update(update())
        self.assertEqual(next_offset, 43)
        self.assertEqual(kube.creates, 1)
        self.assertIn("techne-local-42", kube.jobs)
        self.assertIn("telegram:42:local: completed", self.telegram.messages[-1][1])

    def test_replay_reconciles_existing_job(self) -> None:
        kube = FakeKubernetes(existing=True)
        self.make_controller(kube).handle_update(update())
        self.assertEqual(kube.creates, 0)
        self.assertIn("reconciled", self.telegram.messages[-1][1])

    def test_unauthorised_update_is_ignored(self) -> None:
        kube = FakeKubernetes()
        next_offset = self.make_controller(kube).handle_update(update(user_id=8))
        self.assertEqual(next_offset, 43)
        self.assertEqual(kube.creates, 0)
        self.assertEqual(self.telegram.messages, [])

    def test_pre_baseline_update_is_ignored(self) -> None:
        kube = FakeKubernetes()
        self.make_controller(kube).handle_update(update(update_id=39))
        self.assertEqual(kube.creates, 0)
        self.assertEqual(self.telegram.messages, [])

    def test_failed_job_is_reported(self) -> None:
        kube = FakeKubernetes(failed=True)
        self.make_controller(kube).handle_update(update())
        self.assertIn("failed", self.telegram.messages[-1][1])

    def test_unknown_target_is_reported_without_job(self) -> None:
        kube = FakeKubernetes()
        self.make_controller(kube).handle_update(update(text="/run missing"))
        self.assertEqual(kube.creates, 0)
        self.assertIn("unknown target", self.telegram.messages[-1][1])

    def test_cancel_deletes_deterministic_job(self) -> None:
        kube = FakeKubernetes(existing=True)
        next_offset = self.make_controller(kube).handle_update(
            update(update_id=50, text="/cancel local 42")
        )
        self.assertEqual(next_offset, 51)
        self.assertEqual(kube.deletes, 1)
        self.assertNotIn("techne-local-42", kube.jobs)
        self.assertIn("cancellation requested", self.telegram.messages[-1][1])

    def test_cancel_of_absent_job_is_idempotent(self) -> None:
        kube = FakeKubernetes()
        self.make_controller(kube).handle_update(update(update_id=50, text="/cancel local 42"))
        self.assertEqual(kube.deletes, 0)
        self.assertIn("already absent", self.telegram.messages[-1][1])

    def test_dispatch_does_not_block_cancellation(self) -> None:
        kube = FakeKubernetes()
        workers = []
        controller = self.make_controller(kube, start_worker=workers.append)
        controller.handle_update(update())
        self.assertEqual(len(workers), 1)
        self.assertIn("techne-local-42", kube.jobs)

        controller.handle_update(update(update_id=50, text="/cancel local 42"))
        self.assertNotIn("techne-local-42", kube.jobs)

    def test_startup_reconciles_existing_jobs(self) -> None:
        kube = FakeKubernetes(existing=True)
        self.make_controller(kube).reconcile_existing()
        self.assertIn("telegram:42:local: completed (reconciled)", self.telegram.messages[-1][1])

    def test_target_loader_rejects_duplicates(self) -> None:
        payload = {
            "targets": [
                {"id": "local", "api_server": "https://one", "namespace": "n", "ca_file": "/ca", "token_file": "/t"},
                {"id": "local", "api_server": "https://two", "namespace": "n", "ca_file": "/ca", "token_file": "/t"},
            ]
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "targets.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(controller_module.ControllerError, "duplicate target"):
                controller_module.load_targets(str(path))


if __name__ == "__main__":
    unittest.main()
