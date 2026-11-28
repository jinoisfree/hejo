"""Native Hermes prompt construction and public resolver dispatch."""
import re
from agent.i18n import t
from .reply_rules import styled


def decision(button, owner="나"):
    kind, response = button["kind"], button["response"]
    if kind == "clarify":
        return t("platform.slack.clarify.awaiting" if button.get("other") else "platform.slack.clarify.resolved",
                 user=owner, choice=response)
    catalog = "slash_confirm" if kind == "slash" else "approval"
    return t(f"platform.telegram.{catalog}.resolved_{response}")


def plain_labels(content):
    return re.sub(r"\[\[버튼:\s*([^\]]*)\]\]", lambda m: " / ".join(
        label.strip() for label in m[1].split("|") if label.strip()), content)


def native_metadata(kind, session_key, choices, **fields):
    return styled([{"kind": kind, "session_key": session_key, "label": label[:30],
             "response": response, "style": style or "default", **fields}
            for label, response, style in choices])


async def resolve(button):
    kind = button["kind"]
    if kind == "approval":
        from tools.approval import resolve_gateway_approval
        return bool(resolve_gateway_approval(button["session_key"], button["response"]))
    if kind == "clarify":
        from tools.clarify_gateway import resolve_gateway_clarify, mark_awaiting_text
        if button.get("other"):
            return bool(mark_awaiting_text(button["clarify_id"]))
        return resolve_gateway_clarify(button["clarify_id"], button["response"])
    if kind == "slash":
        from tools.slash_confirm import resolve as resolve_slash
        return await resolve_slash(button["session_key"], button["confirm_id"], button["response"]) is not None
    return False
