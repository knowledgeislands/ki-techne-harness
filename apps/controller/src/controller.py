#!/usr/bin/env python3
"""Dependency-free Telegram-to-Kubernetes proof controller."""

from __future__ import annotations

import json
import logging
import os
import re
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


LOG = logging.getLogger("techne-controller")
JOB_PREFIX = "techne"
DEFAULT_IMAGE = "docker.io/library/busybox@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662"


class ControllerError(RuntimeError):
    """A bounded controller failure safe to report to the operator."""


class ApiError(ControllerError):
    """An HTTP API returned a non-success response."""

    def __init__(self, service: str, status: int, reason: str) -> None:
        super().__init__(f"{service} returned HTTP {status}: {reason}")
        self.service = service
        self.status = status


@dataclass(frozen=True)
class Target:
    id: str
    api_server: str
    namespace: str
    ca_file: str
    token_file: str


@dataclass(frozen=True)
class ExecutionResult:
    execution_id: str
    job_name: str
    target_id: str
    outcome: str
    logs: str
    reconciled: bool


def read_secret(path: str) -> str:
    value = Path(path).read_text(encoding="utf-8").strip()
    if not value:
        raise ControllerError(f"secret file is empty: {path}")
    return value


def load_targets(path: str) -> dict[str, Target]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    entries = payload.get("targets")
    if not isinstance(entries, list) or not entries:
        raise ControllerError("target configuration must contain a non-empty targets list")

    targets: dict[str, Target] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise ControllerError("each target must be an object")
        target = Target(
            id=str(entry["id"]),
            api_server=str(entry["api_server"]).rstrip("/"),
            namespace=str(entry["namespace"]),
            ca_file=str(entry["ca_file"]),
            token_file=str(entry["token_file"]),
        )
        if not re.fullmatch(r"[a-z0-9](?:[-a-z0-9]{0,61}[a-z0-9])?", target.id):
            raise ControllerError(f"target id is not a DNS label: {target.id}")
        if target.id in targets:
            raise ControllerError(f"duplicate target id: {target.id}")
        targets[target.id] = target
    return targets


def execution_identity(update_id: int, target_id: str) -> tuple[str, str]:
    execution_id = f"telegram:{update_id}:{target_id}"
    safe_target = re.sub(r"[^a-z0-9-]", "-", target_id.lower()).strip("-")
    job_name = f"{JOB_PREFIX}-{safe_target}-{update_id}"[:63].rstrip("-")
    return execution_id, job_name


def build_job(execution_id: str, job_name: str, image: str = DEFAULT_IMAGE) -> dict[str, Any]:
    label_id = job_name.removeprefix(f"{JOB_PREFIX}-")
    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {
            "name": job_name,
            "labels": {
                "app.kubernetes.io/name": "techne-execution",
                "techne.knowledgeislands.dev/execution": label_id,
            },
            "annotations": {"techne.knowledgeislands.dev/execution-id": execution_id},
        },
        "spec": {
            "backoffLimit": 0,
            "activeDeadlineSeconds": 300,
            "template": {
                "metadata": {
                    "labels": {
                        "app.kubernetes.io/name": "techne-execution",
                        "techne.knowledgeislands.dev/execution": label_id,
                    }
                },
                "spec": {
                    "automountServiceAccountToken": False,
                    "restartPolicy": "Never",
                    "serviceAccountName": "techne-execution",
                    "securityContext": {
                        "runAsNonRoot": True,
                        "seccompProfile": {"type": "RuntimeDefault"},
                    },
                    "containers": [
                        {
                            "name": "workload",
                            "image": image,
                            "imagePullPolicy": "IfNotPresent",
                            "command": [
                                "/bin/sh",
                                "-c",
                                f"printf '%s\\n' '{json.dumps({'execution_id': execution_id, 'outcome': 'completed'}, separators=(',', ':'))}'",
                            ],
                            "resources": {
                                "requests": {"cpu": "10m", "memory": "16Mi"},
                                "limits": {"cpu": "100m", "memory": "64Mi"},
                            },
                            "securityContext": {
                                "allowPrivilegeEscalation": False,
                                "capabilities": {"drop": ["ALL"]},
                                "readOnlyRootFilesystem": True,
                                "runAsNonRoot": True,
                                "runAsUser": 65534,
                            },
                        }
                    ],
                },
            },
        },
    }


class TelegramClient:
    def __init__(self, token_file: str, expected_username: str, timeout: int = 35) -> None:
        self._token_file = token_file
        self._expected_username = expected_username.lstrip("@").lower()
        self._timeout = timeout

    def _call(self, method: str, payload: dict[str, Any] | None = None) -> Any:
        token = read_secret(self._token_file)
        url = f"https://api.telegram.org/bot{token}/{method}"
        data = None
        headers = {"Accept": "application/json"}
        if payload is not None:
            data = urllib.parse.urlencode(
                {
                    key: json.dumps(value, separators=(",", ":")) if isinstance(value, (list, dict)) else str(value)
                    for key, value in payload.items()
                }
            ).encode("utf-8")
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        request = urllib.request.Request(url, data=data, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=self._timeout) as response:
                body = json.load(response)
        except urllib.error.HTTPError as error:
            raise ApiError("Telegram", error.code, error.reason) from None
        except (urllib.error.URLError, TimeoutError) as error:
            raise ControllerError(f"Telegram transport failed: {type(error).__name__}") from None
        if not body.get("ok"):
            raise ControllerError(f"Telegram rejected {method}")
        return body.get("result")

    def preflight(self) -> dict[str, Any]:
        identity = self._call("getMe")
        username = str(identity.get("username", "")).lower()
        if username != self._expected_username:
            raise ControllerError(
                f"Telegram identity mismatch: expected @{self._expected_username}, received @{username or 'unknown'}"
            )
        webhook = self._call("getWebhookInfo")
        if webhook.get("url"):
            raise ControllerError("Telegram bot has an active webhook; refusing to displace it")
        return {
            "id": identity.get("id"),
            "username": identity.get("username"),
            "pending_update_count": webhook.get("pending_update_count", 0),
        }

    def get_updates(self, offset: int | None) -> list[dict[str, Any]]:
        payload: dict[str, Any] = {"timeout": 30, "limit": 20, "allowed_updates": ["message"]}
        if offset is not None:
            payload["offset"] = offset
        result = self._call("getUpdates", payload)
        return result if isinstance(result, list) else []

    def send_message(self, chat_id: int, text: str) -> None:
        self._call("sendMessage", {"chat_id": chat_id, "text": text})


class KubernetesClient:
    def __init__(self, target: Target, timeout: int = 20) -> None:
        self.target = target
        self.timeout = timeout

    def _request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        url = f"{self.target.api_server}{path}"
        data = None if body is None else json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {read_secret(self.target.token_file)}",
        }
        if data is not None:
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        context = ssl.create_default_context(cafile=self.target.ca_file)
        try:
            with urllib.request.urlopen(request, context=context, timeout=self.timeout) as response:
                if response.status == 204:
                    return None
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise ApiError(f"Kubernetes target {self.target.id}", error.code, error.reason) from None
        except (urllib.error.URLError, TimeoutError) as error:
            raise ControllerError(
                f"Kubernetes target {self.target.id} transport failed: {type(error).__name__}"
            ) from None

    def get_job(self, name: str) -> dict[str, Any] | None:
        path = f"/apis/batch/v1/namespaces/{self.target.namespace}/jobs/{name}"
        try:
            return self._request("GET", path)
        except ApiError as error:
            if error.status == 404:
                return None
            raise

    def create_job(self, job: dict[str, Any]) -> dict[str, Any]:
        path = f"/apis/batch/v1/namespaces/{self.target.namespace}/jobs"
        try:
            return self._request("POST", path, job)
        except ApiError as error:
            if error.status == 409:
                existing = self.get_job(job["metadata"]["name"])
                if existing is not None:
                    return existing
            raise

    def list_jobs(self) -> list[dict[str, Any]]:
        selector = urllib.parse.quote("app.kubernetes.io/name=techne-execution")
        path = f"/apis/batch/v1/namespaces/{self.target.namespace}/jobs?labelSelector={selector}"
        payload = self._request("GET", path)
        return list(payload.get("items", []))

    def delete_job(self, name: str) -> bool:
        path = f"/apis/batch/v1/namespaces/{self.target.namespace}/jobs/{name}"
        try:
            self._request(
                "DELETE",
                path,
                {
                    "apiVersion": "v1",
                    "kind": "DeleteOptions",
                    "gracePeriodSeconds": 0,
                    "propagationPolicy": "Foreground",
                },
            )
        except ApiError as error:
            if error.status == 404:
                return False
            raise
        return True

    def pod_name(self, job_name: str) -> str | None:
        selector = urllib.parse.quote(f"job-name={job_name}")
        path = f"/api/v1/namespaces/{self.target.namespace}/pods?labelSelector={selector}"
        payload = self._request("GET", path)
        items = payload.get("items", [])
        return str(items[0]["metadata"]["name"]) if items else None

    def pod_logs(self, pod_name: str) -> str:
        path = f"/api/v1/namespaces/{self.target.namespace}/pods/{pod_name}/log"
        token = read_secret(self.target.token_file)
        request = urllib.request.Request(
            f"{self.target.api_server}{path}",
            headers={"Accept": "text/plain", "Authorization": f"Bearer {token}"},
            method="GET",
        )
        context = ssl.create_default_context(cafile=self.target.ca_file)
        try:
            with urllib.request.urlopen(request, context=context, timeout=self.timeout) as response:
                return response.read().decode("utf-8", errors="replace").strip()
        except urllib.error.HTTPError as error:
            raise ApiError(f"Kubernetes target {self.target.id}", error.code, error.reason) from None


class Controller:
    def __init__(
        self,
        telegram: Any,
        targets: dict[str, Target],
        operator_user_id: int,
        operator_chat_id: int,
        initial_offset: int,
        kube_factory: Callable[[Target], Any] = KubernetesClient,
        sleep: Callable[[float], None] = time.sleep,
        monotonic: Callable[[], float] = time.monotonic,
        start_worker: Callable[[Callable[[], None]], None] | None = None,
        execution_timeout: int = 360,
    ) -> None:
        self.telegram = telegram
        self.targets = targets
        self.operator_user_id = operator_user_id
        self.operator_chat_id = operator_chat_id
        self.initial_offset = initial_offset
        self.kube_factory = kube_factory
        self.sleep = sleep
        self.monotonic = monotonic
        self.start_worker = start_worker or self._start_thread
        self.execution_timeout = execution_timeout

    @staticmethod
    def _start_thread(callback: Callable[[], None]) -> None:
        threading.Thread(target=callback, daemon=True).start()

    def _authorised_message(self, update: dict[str, Any]) -> dict[str, Any] | None:
        message = update.get("message")
        if not isinstance(message, dict):
            return None
        sender = message.get("from", {})
        chat = message.get("chat", {})
        if (
            sender.get("id") != self.operator_user_id
            or chat.get("id") != self.operator_chat_id
            or chat.get("type") != "private"
        ):
            LOG.warning("ignored unauthorised Telegram update %s", update.get("update_id"))
            return None
        if int(update["update_id"]) < self.initial_offset:
            LOG.info("ignored pre-baseline Telegram update %s", update.get("update_id"))
            return None
        return message

    def _observe(self, kube: Any, execution_id: str, job_name: str, target_id: str, reconciled: bool) -> ExecutionResult:
        deadline = self.monotonic() + self.execution_timeout
        while self.monotonic() < deadline:
            job = kube.get_job(job_name)
            if job is None:
                raise ControllerError(f"execution disappeared: {execution_id}")
            conditions = {condition.get("type"): condition for condition in job.get("status", {}).get("conditions", [])}
            if conditions.get("Complete", {}).get("status") == "True":
                pod = kube.pod_name(job_name)
                logs = kube.pod_logs(pod) if pod else ""
                return ExecutionResult(execution_id, job_name, target_id, "completed", logs, reconciled)
            if conditions.get("Failed", {}).get("status") == "True":
                pod = kube.pod_name(job_name)
                logs = kube.pod_logs(pod) if pod else ""
                return ExecutionResult(execution_id, job_name, target_id, "failed", logs, reconciled)
            self.sleep(2)
        return ExecutionResult(execution_id, job_name, target_id, "timed-out", "", reconciled)

    def _report_execution(
        self,
        kube: Any,
        execution_id: str,
        job_name: str,
        target_id: str,
        reconciled: bool,
    ) -> None:
        try:
            result = self._observe(kube, execution_id, job_name, target_id, reconciled)
            replay = " (reconciled)" if result.reconciled else ""
            self.telegram.send_message(
                self.operator_chat_id,
                f"{result.execution_id}: {result.outcome}{replay}\n{result.logs}".rstrip(),
            )
        except ControllerError as error:
            self.telegram.send_message(self.operator_chat_id, f"Execution failed: {error}")

    def dispatch(self, update_id: int, target_id: str) -> tuple[str, str, bool]:
        target = self.targets.get(target_id)
        if target is None:
            raise ControllerError(f"unknown target: {target_id}")
        execution_id, job_name = execution_identity(update_id, target_id)
        kube = self.kube_factory(target)
        existing = kube.get_job(job_name)
        reconciled = existing is not None
        if existing is None:
            kube.create_job(build_job(execution_id, job_name))
        self.start_worker(
            lambda: self._report_execution(kube, execution_id, job_name, target_id, reconciled)
        )
        return execution_id, job_name, reconciled

    def reconcile_existing(self) -> None:
        for target_id, target in self.targets.items():
            kube = self.kube_factory(target)
            for job in kube.list_jobs():
                metadata = job.get("metadata", {})
                execution_id = metadata.get("annotations", {}).get(
                    "techne.knowledgeislands.dev/execution-id"
                )
                job_name = metadata.get("name")
                if not isinstance(execution_id, str) or not isinstance(job_name, str):
                    continue
                self.start_worker(
                    lambda kube=kube, execution_id=execution_id, job_name=job_name, target_id=target_id: self._report_execution(
                        kube, execution_id, job_name, target_id, True
                    )
                )

    def cancel(self, target_id: str, execution_update_id: int) -> tuple[str, bool]:
        target = self.targets.get(target_id)
        if target is None:
            raise ControllerError(f"unknown target: {target_id}")
        _, job_name = execution_identity(execution_update_id, target_id)
        return job_name, self.kube_factory(target).delete_job(job_name)

    def handle_update(self, update: dict[str, Any]) -> int:
        update_id = int(update["update_id"])
        message = self._authorised_message(update)
        if message is None:
            return update_id + 1
        text = str(message.get("text", "")).strip()
        parts = text.split()
        command = parts[0].split("@", 1)[0] if parts else ""
        if command == "/start" or command == "/help":
            self.telegram.send_message(
                self.operator_chat_id,
                "Commands: /run <target>, /cancel <target> <execution-update-id>, /targets",
            )
            return update_id + 1
        if command == "/targets":
            self.telegram.send_message(self.operator_chat_id, "Targets: " + ", ".join(sorted(self.targets)))
            return update_id + 1
        if command == "/cancel" and len(parts) == 3:
            try:
                job_name, deleted = self.cancel(parts[1], int(parts[2]))
                outcome = "cancellation requested" if deleted else "already absent"
                self.telegram.send_message(self.operator_chat_id, f"{job_name}: {outcome}")
            except (ControllerError, ValueError) as error:
                self.telegram.send_message(self.operator_chat_id, f"Rejected: {error}")
            return update_id + 1
        if command != "/run" or len(parts) != 2:
            self.telegram.send_message(
                self.operator_chat_id,
                "Usage: /run <target> or /cancel <target> <execution-update-id>",
            )
            return update_id + 1

        target_id = parts[1]
        self.telegram.send_message(self.operator_chat_id, f"Dispatching update {update_id} to {target_id}")
        try:
            self.dispatch(update_id, target_id)
        except ControllerError as error:
            self.telegram.send_message(self.operator_chat_id, f"Update {update_id} failed: {error}")
        return update_id + 1

    def run(self) -> None:
        offset: int | None = self.initial_offset
        while True:
            for update in self.telegram.get_updates(offset):
                offset = self.handle_update(update)


def require_int(name: str) -> int:
    value = os.environ.get(name)
    if value is None:
        raise ControllerError(f"missing environment variable: {name}")
    try:
        return int(value)
    except ValueError:
        raise ControllerError(f"environment variable must be an integer: {name}") from None


def main() -> None:
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(message)s")
    telegram = TelegramClient(
        token_file=os.environ.get("TELEGRAM_BOT_TOKEN_FILE", "/var/run/secrets/techne/telegram-token"),
        expected_username=os.environ.get("TELEGRAM_BOT_USERNAME", "kitteth_bot"),
    )
    preflight = telegram.preflight()
    LOG.info(
        "Telegram preflight passed for @%s with %s pending updates",
        preflight["username"],
        preflight["pending_update_count"],
    )
    controller = Controller(
        telegram=telegram,
        targets=load_targets(os.environ.get("TARGETS_FILE", "/etc/techne/targets.json")),
        operator_user_id=require_int("TELEGRAM_OPERATOR_USER_ID"),
        operator_chat_id=require_int("TELEGRAM_OPERATOR_CHAT_ID"),
        initial_offset=require_int("TELEGRAM_INITIAL_OFFSET"),
    )
    controller.reconcile_existing()
    controller.run()


if __name__ == "__main__":
    main()
