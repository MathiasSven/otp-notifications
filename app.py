#!/usr/bin/env python3

# pyright: reportMissingModuleSource=false

import logging
import os
import subprocess
import threading

import gi
import uvicorn
from fastapi import FastAPI, Response
from pydantic import BaseModel

gi.require_version("Notify", "0.7")

# https://lazka.github.io/pgi-docs/Notify-0.7/classes/Notification.html
from gi.repository import GLib, Notify

logger = logging.getLogger("uvicorn.error")

Notify.init("SMS OTP Messages")

class OTPMessage(BaseModel):
    sender: str
    code: str
    content: str

_active_notifications: set[Notify.Notification] = set()

def mk_notification(message: OTPMessage) -> None:
    notification = Notify.Notification.new(
        summary=f"Sender: {message.sender}",
        body=f"Received OTP: {message.code}",
        icon=None,
    )
    notification.set_hint("transient", GLib.Variant("b", True))
    notification.set_timeout(10000)
    _active_notifications.add(notification)

    def callback(*args, **kwargs):
        try:
            subprocess.run(
                ["wl-copy", "--sensitive", "--type", "text/plain"],
                input=message.code,
                text=True,
                check=True,
            )
        except (OSError, subprocess.CalledProcessError):
            logger.exception("Could not copy OTP to the Wayland clipboard")
        else:
            logger.debug("Copied OTP to the Wayland clipboard")

    def closed_callback(closed_notification):
        _active_notifications.discard(closed_notification)
        logger.debug("Notification closed")

    notification.connect("closed", closed_callback)
    notification.add_action("copy", "Copy to Clipboard", callback)
    notification.show()


app = FastAPI()


@app.post("/")
async def root(message: OTPMessage):
    GLib.idle_add(mk_notification, message)
    return Response(status_code=200)


def run_api(main_loop: GLib.MainLoop):
    try:
        host = os.environ.get("OTP_NOTIFICATIONS_HOST", "0.0.0.0")
        port = os.environ.get("OTP_NOTIFICATIONS_PORT", 8429)
        uvicorn.run(app, host=host, port=int(port), log_level="debug")
    finally:
        logger.info("Shutting down GLib MainLoop")
        GLib.idle_add(main_loop.quit)


def main():
    main_loop = GLib.MainLoop()
    api_thread = threading.Thread(target=run_api, args=(main_loop,), daemon=True)
    api_thread.start()
    main_loop.run()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        raise SystemExit(1)
