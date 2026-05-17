import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "hermes-profile-router.py"
spec = importlib.util.spec_from_file_location("hermes_profile_router", SCRIPT)
assert spec is not None and spec.loader is not None
router = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = router
spec.loader.exec_module(router)


def profiles():
    return [
        router.Profile(
            name="worker",
            summary="Cheap, fast worker for simple local sysadmin, file inspection, and small terminal tasks.",
            tags=["cheap", "fast", "simple", "sysadmin", "terminal", "files"],
            use_for=["file checks, ports, process/disk/service/log status, simple scripts, summaries"],
            avoid_for=["coding", "NixOS config changes", "Hermes config changes", "web research", "media generation"],
            priority=60,
        ),
        router.Profile(
            name="planner",
            summary="Smart planning profile for implementation plans, architecture decomposition, and task breakdown.",
            tags=["planning", "architecture", "decomposition", "plan", "tasks"],
            use_for=["implementation plans, architecture decomposition, task breakdown"],
            priority=75,
        ),
        router.Profile(
            name="research-worker",
            summary="Web/current facts/papers/market/domain research worker.",
            tags=["research", "web", "current", "news", "papers", "arxiv", "market", "polymarket"],
            use_for=["web/current facts/news/papers/arxiv/polymarket/market/domain reconnaissance"],
            priority=75,
        ),
        router.Profile(
            name="productivity-worker",
            summary="Email, docs, calendar, sheets, Notion, Airtable, Linear, PDF, and reporting worker.",
            tags=["email", "calendar", "docs", "sheets", "notion", "airtable", "linear", "pdf", "reporting"],
            use_for=["email/calendar/docs/sheets/notion/airtable/linear/pdf/reporting"],
            priority=75,
        ),
        router.Profile(
            name="media-worker",
            summary="Media and creative production worker with vision, image, video, and TTS tools.",
            tags=["media", "creative", "image", "video", "audio", "tts", "vision", "design"],
            use_for=["video, audio, TTS, music, GIFs, thumbnails, posters, creative media workflows"],
            avoid_for=["cheap one-command sysadmin tasks"],
            priority=80,
        ),
        router.Profile(
            name="codex-worker",
            summary="Coding and declarative Nix/Hermes configuration worker using the Codex subscription model.",
            tags=["coding", "debugging", "repo", "tests", "git", "github", "nixos", "hermes", "profiles", "router"],
            use_for=["software development, debugging, tests, refactors, repository edits", "NixOS/dotfiles/Hermes Agent config/profile/router/toolset/provider/service/package changes", "GitHub/PR work"],
            priority=70,
        ),
        router.Profile(
            name="fallback-full",
            summary="Last resort full-tool/full-skill profile for unknown execution.",
            tags=["fallback", "full", "general", "unknown"],
            use_for=["low-confidence unknown execution"],
            fallback=True,
            priority=95,
        ),
        router.Profile(
            name="knowledge-curator",
            summary="Knowledge, memory, wiki, session, and note-curation worker.",
            tags=["knowledge", "wiki", "memory", "sessions", "notes", "curation", "index"],
            use_for=["wiki updates, memory hygiene, session summaries, knowledge-base indexing"],
            priority=65,
        ),
        router.Profile(
            name="session-indexer",
            summary="Specialized scheduled worker for indexing and summarizing Hermes session logs.",
            tags=["sessions", "index", "summaries", "scheduled", "knowledge"],
            use_for=["session indexing jobs, transcript summarization, search-index maintenance"],
            avoid_for=["interactive user tasks unless explicitly about session indexing"],
            priority=30,
        ),
        router.Profile(
            name="wiki-linter",
            summary="Specialized scheduled worker for linting Otto wiki pages and knowledge docs.",
            tags=["wiki", "lint", "knowledge", "scheduled"],
            use_for=["wiki linting, contradiction scans, knowledge doc hygiene"],
            avoid_for=["interactive user tasks unless explicitly about wiki linting"],
            priority=30,
        ),
    ]


class ProfileRouterPlanTests(unittest.TestCase):
    def test_conditional_media_request_plans_worker_check_then_media_create(self):
        result = router.plan("check if we have a video called xx, if not then create a video", profiles())

        self.assertEqual(result["strategy"], "conditional")
        self.assertEqual([step["profile"] for step in result["steps"]], ["worker", "media-worker"])
        self.assertEqual(result["steps"][0]["id"], "check-existing")
        self.assertEqual(result["steps"][1]["condition"], "only if check-existing reports not found")
        self.assertIn("Do not create", result["steps"][0]["task"])
        self.assertIn("Only create", result["steps"][1]["task"])

    def test_atomic_media_request_still_uses_single_media_step(self):
        result = router.plan("create a short intro video for Otto", profiles())

        self.assertEqual(result["strategy"], "atomic")
        self.assertEqual(len(result["steps"]), 1)
        self.assertEqual(result["steps"][0]["profile"], "media-worker")

    def test_short_image_generation_request_uses_media_worker(self):
        result = router.plan("make an image of Otto as a fox", profiles())

        self.assertEqual(result["strategy"], "atomic")
        self.assertEqual(result["steps"][0]["profile"], "media-worker")

    def test_short_video_request_does_not_fall_back_from_low_evidence(self):
        result = router.plan("make a video", profiles())

        self.assertEqual(result["strategy"], "atomic")
        self.assertEqual(result["steps"][0]["profile"], "media-worker")
        self.assertNotEqual(result["steps"][0]["profile"], "fallback-full")

    def test_conditional_non_media_request_uses_worker_then_best_specialist(self):
        result = router.plan("check if the repo has failing tests, if not add a small feature", profiles())

        self.assertEqual(result["strategy"], "conditional")
        self.assertEqual(result["steps"][0]["profile"], "worker")
        self.assertEqual(result["steps"][1]["profile"], "codex-worker")

    def test_explicit_scheduled_wiki_scan_prefers_wiki_linter(self):
        result = router.plan("run the monthly wiki contradiction scan", profiles())

        self.assertEqual(result["strategy"], "atomic")
        self.assertEqual(result["steps"][0]["profile"], "wiki-linter")

    def test_explicit_session_indexing_prefers_session_indexer(self):
        result = router.plan("index new Hermes session logs", profiles())

        self.assertEqual(result["strategy"], "atomic")
        self.assertEqual(result["steps"][0]["profile"], "session-indexer")

    def test_unknown_request_uses_fallback(self):
        result = router.plan("do the thing", profiles())

        self.assertEqual(result["strategy"], "atomic")
        self.assertEqual(result["steps"][0]["profile"], "fallback-full")

    def test_nixos_profile_edits_use_codex_worker(self):
        result = router.plan("edit nixos config for hermes profiles", profiles())

        self.assertEqual(result["steps"][0]["profile"], "codex-worker")

    def test_hermes_provider_config_uses_codex_worker(self):
        result = router.plan("configure Hermes Agent fallback providers", profiles())

        self.assertEqual(result["steps"][0]["profile"], "codex-worker")

    def test_port_check_uses_worker(self):
        result = router.plan("check port 443 and summarize what is listening", profiles())

        self.assertEqual(result["steps"][0]["profile"], "worker")

    def test_current_news_uses_research_worker(self):
        result = router.plan("look up current news about OpenAI", profiles())

        self.assertEqual(result["steps"][0]["profile"], "research-worker")

    def test_email_report_uses_productivity_worker(self):
        result = router.plan("send Berker an email report", profiles())

        self.assertEqual(result["steps"][0]["profile"], "productivity-worker")

    def test_implementation_plan_uses_planner(self):
        result = router.plan("write a careful implementation plan for profile routing", profiles())

        self.assertEqual(result["steps"][0]["profile"], "planner")

    def test_chat_only_opinion_uses_default(self):
        result = router.plan("what do you think about my profile architecture? chat only", profiles())

        self.assertEqual(result["steps"][0]["profile"], "default")

    def test_nixos_config_review_uses_codex_worker_not_worker(self):
        result = router.plan("check our nixos config and make sure everything is up to snuff", profiles())

        self.assertEqual(result["steps"][0]["profile"], "codex-worker")

    def test_session_history_wiki_update_uses_knowledge_not_research(self):
        result = router.plan("search recent sessions and update the Otto wiki", profiles())

        self.assertEqual(result["steps"][0]["profile"], "knowledge-curator")

    def test_session_log_summary_uses_knowledge_curator(self):
        result = router.plan("summarize recent session logs for durable notes", profiles())

        self.assertEqual(result["steps"][0]["profile"], "knowledge-curator")

    def test_alias_expansion_does_not_swamp_narrow_wiki_routes(self):
        tokens = router.tokenize("wiki")

        self.assertEqual(tokens, {"wiki", "knowledge"})
        self.assertNotIn("memory", tokens)
        self.assertNotIn("notes", tokens)
        self.assertNotIn("index", tokens)
        self.assertNotIn("summarize", tokens)

    def test_low_evidence_check_does_not_select_worker_from_check_word_alone(self):
        result = router.plan("check", profiles())

        self.assertEqual(result["steps"][0]["profile"], "fallback-full")
        self.assertNotEqual(result["steps"][0]["profile"], "worker")

    def test_add_cron_job_uses_codex_worker(self):
        result = router.plan("add a cron job that watches disk usage", profiles())

        self.assertEqual(result["steps"][0]["profile"], "codex-worker")


if __name__ == "__main__":
    unittest.main()
