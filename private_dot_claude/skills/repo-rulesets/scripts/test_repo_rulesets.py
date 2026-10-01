"""Offline tests for repo-rulesets. Run: python3 -m unittest discover -s <this dir>."""

import importlib.machinery
import importlib.util
import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parent / "executable_repo-rulesets"
_loader = importlib.machinery.SourceFileLoader("repo_rulesets", str(SCRIPT))
_spec = importlib.util.spec_from_loader("repo_rulesets", _loader)
rr = importlib.util.module_from_spec(_spec)
_loader.exec_module(rr)

CONFORMING_CI = """
on:
  push:
    branches: [main]
  pull_request:
jobs:
  std:
    uses: HJewkes/ci/.github/workflows/node.yml@v1
  check:
    if: always()
    needs: [std]
    runs-on: ubuntu-latest
    steps:
      - uses: HJewkes/ci/actions/all-green@v1
"""

LOCAL_ALL_GREEN_CI = CONFORMING_CI.replace("HJewkes/ci/actions/all-green@v1", "./actions/all-green")


class ConformanceTest(unittest.TestCase):
    def test_check_job_using_all_green_conforms(self):
        self.assertEqual(rr.conformance("HJewkes/x", {"ci.yml": CONFORMING_CI}), (True, None))

    def test_missing_ci_yml_is_legacy(self):
        conforms, reason = rr.conformance("HJewkes/x", {"build.yml": CONFORMING_CI})
        self.assertFalse(conforms)
        self.assertIn("no .github/workflows/ci.yml", reason)

    def test_check_job_without_all_green_is_legacy(self):
        ci = CONFORMING_CI.replace("HJewkes/ci/actions/all-green@v1", "actions/checkout@v4")
        conforms, reason = rr.conformance("HJewkes/x", {"ci.yml": ci})
        self.assertFalse(conforms)
        self.assertIn("does not use", reason)

    def test_local_all_green_counts_only_inside_the_ci_repo(self):
        self.assertTrue(rr.conformance("HJewkes/ci", {"ci.yml": LOCAL_ALL_GREEN_CI})[0])
        self.assertFalse(rr.conformance("HJewkes/x", {"ci.yml": LOCAL_ALL_GREEN_CI})[0])

    def test_lookalike_action_owner_does_not_conform(self):
        ci = CONFORMING_CI.replace("HJewkes/ci/", "Evil/ci/")
        self.assertFalse(rr.conformance("HJewkes/x", {"ci.yml": ci})[0])


class NeedsCoverageTest(unittest.TestCase):
    def test_check_job_that_skips_a_job_does_not_conform(self):
        ci = CONFORMING_CI.replace("  check:", "  extra:\n    runs-on: ubuntu-latest\n  check:")
        conforms, reason = rr.conformance("HJewkes/x", {"ci.yml": ci})
        self.assertFalse(conforms)
        self.assertIn("does not need: extra", reason)

    def test_needs_given_as_a_string_is_accepted(self):
        ci = CONFORMING_CI.replace("needs: [std]", "needs: std")
        self.assertTrue(rr.conformance("HJewkes/x", {"ci.yml": ci})[0])


class SelectChecksTest(unittest.TestCase):
    def test_conforming_repo_requires_only_pinned_check_without_discovery(self):
        with mock.patch.object(rr, "discover_checks") as discover:
            checks = rr.select_checks("HJewkes/x", "main", {}, {"ci.yml": CONFORMING_CI})
        discover.assert_not_called()
        self.assertEqual(
            rr.required_contexts(checks), [{"context": "check", "integration_id": 15368}]
        )

    def test_non_conforming_repo_keeps_discovery_and_is_flagged_legacy(self):
        found = {"required": ["test", "lint"], "source": "discovery"}
        with mock.patch.object(rr, "discover_checks", return_value=found):
            checks = rr.select_checks("HJewkes/x", "main", {}, {})
        self.assertEqual(rr.required_contexts(checks), [{"context": "test"}, {"context": "lint"}])
        self.assertIn("no .github/workflows/ci.yml", checks["legacy"])

    def test_override_wins_over_the_standard(self):
        override = {"required_checks": ["test"]}
        checks = rr.select_checks("HJewkes/x", "main", override, {"ci.yml": CONFORMING_CI})
        self.assertEqual(rr.required_contexts(checks), [{"context": "test"}])

    def test_override_keeps_the_pin_on_check(self):
        override = {"required_checks": ["check", "test"]}
        checks = rr.select_checks("HJewkes/x", "main", override, {"ci.yml": CONFORMING_CI})
        self.assertEqual(
            rr.required_contexts(checks),
            [{"context": "check", "integration_id": 15368}, {"context": "test"}],
        )

    def test_override_on_a_conforming_repo_is_flagged(self):
        override = {"required_checks": ["test"]}
        checks = rr.select_checks("HJewkes/x", "main", override, {"ci.yml": CONFORMING_CI})
        self.assertTrue(checks["override_conforms"])

    def test_desired_ruleset_carries_the_pin(self):
        desired = rr.build_desired({"required": ["check"], "standard": True}, {})
        rule = next(
            r for r in desired["no-direct-push"]["rules"] if r["type"] == "required_status_checks"
        )
        self.assertEqual(
            rule["parameters"]["required_status_checks"],
            [{"context": "check", "integration_id": 15368}],
        )


class PrTriggerFiltersTest(unittest.TestCase):
    def filters(self, on_block):
        return rr.pr_trigger_filters(rr.parse_workflow(on_block + "\njobs: {}\n"))

    def test_bare_pull_request_has_no_filters(self):
        self.assertEqual(self.filters("on:\n  pull_request:"), [])

    def test_string_and_list_forms_have_no_filters(self):
        self.assertEqual(self.filters("on: pull_request"), [])
        self.assertEqual(self.filters("on: [push, pull_request]"), [])

    def test_paths_and_branches_filters_are_reported(self):
        on = "on:\n  pull_request:\n    branches: [main]\n    paths-ignore: ['docs/**']"
        self.assertEqual(self.filters(on), ["paths-ignore", "branches"])

    def test_missing_pull_request_trigger_is_none(self):
        self.assertIsNone(self.filters("on:\n  push:"))


class StandardProblemsTest(unittest.TestCase):
    def problems(self, workflows, runs_by_sha):
        prs = [{"number": 7, "sha": "a"}, {"number": 8, "sha": "b"}]

        def fake_gh_json(path, jq):
            return runs_by_sha[path.split("/commits/")[1].split("/")[0]]

        with mock.patch.object(rr, "gh_json", side_effect=fake_gh_json):
            return rr.standard_problems("HJewkes/x", prs, workflows)

    def test_clean_repo_has_no_problems(self):
        ran = [{"status": "completed", "app": 15368}]
        self.assertEqual(self.problems({"ci.yml": CONFORMING_CI}, {"a": ran, "b": ran}), [])

    def test_filtered_trigger_and_second_check_job_and_missing_run_are_reported(self):
        ci = CONFORMING_CI.replace("  pull_request:", "  pull_request:\n    paths: ['src/**']")
        other = "on: push\njobs:\n  check:\n    runs-on: ubuntu-latest\n"
        ran = [{"status": "completed", "app": 15368}]
        wrong_app = [{"status": "completed", "app": 99}]
        problems = self.problems({"ci.yml": ci, "lint.yml": other}, {"a": ran, "b": wrong_app})
        self.assertEqual(
            problems,
            [
                "ci.yml pull_request trigger is filtered (paths)",
                "lint.yml also has a job named `check`",
                "merged PR #8 has no completed `check` from GitHub Actions",
            ],
        )

    def test_second_check_job_inside_ci_yml_is_reported(self):
        ci = CONFORMING_CI.replace("  std:", "  lint:\n    name: check\n    runs-on: x\n  std:")
        ci = ci.replace("needs: [std]", "needs: [std, lint]")
        ran = [{"status": "completed", "app": 15368}]
        problems = self.problems({"ci.yml": ci}, {"a": ran, "b": ran})
        self.assertEqual(problems, ["ci.yml has a second job named `check`"])

    def test_in_progress_check_does_not_count_as_concluded(self):
        pending = [{"status": "in_progress", "app": 15368}]
        ran = [{"status": "completed", "app": 15368}]
        problems = self.problems({"ci.yml": CONFORMING_CI}, {"a": pending, "b": ran})
        self.assertEqual(problems, ["merged PR #7 has no completed `check` from GitHub Actions"])


class StandardNotesTest(unittest.TestCase):
    def notes(self, plan):
        out = io.StringIO()
        with redirect_stdout(out):
            rr.print_standard_notes(plan)
        return out.getvalue()

    def test_zero_sampled_prs_is_stated(self):
        self.assertIn("0 merged PRs sampled", self.notes({"checks": {}, "sampled_prs": []}))

    def test_sampled_prs_print_nothing(self):
        self.assertEqual(self.notes({"checks": {}, "sampled_prs": [{"number": 1}]}), "")

    def test_override_on_a_conforming_repo_prints_a_warning(self):
        plan = {"checks": {"override_conforms": True}, "sampled_prs": [{"number": 1}]}
        self.assertIn("WARNING", self.notes(plan))


class BotTokenWarningTest(unittest.TestCase):
    def test_changesets_with_github_token_still_warns(self):
        release = (
            "steps:\n  - uses: changesets/action@v1\n"
            "    env:\n      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}\n"
        )
        self.assertEqual(rr.bot_token_workflows({"release.yml": release}), ["release.yml"])


if __name__ == "__main__":
    unittest.main()
