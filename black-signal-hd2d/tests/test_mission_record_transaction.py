"""Regression guard for mission completion when Android record persistence fails.

Run: python3 -m unittest discover -s tests -p 'test_mission_record_transaction.py'
This source-level guard is not a substitute for Godot runtime/device tests.
"""
import pathlib
import unittest

MISSION = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "mission.gd"


class MissionRecordTransactionTests(unittest.TestCase):
    def test_failed_save_rolls_back_record_not_completed_mission(self):
        source = MISSION.read_text(encoding="utf-8")
        start = source.index("if phase==Phase.EXTRACT and kills>=REQUIRED_KILLS:", source.index("func interact("))
        end = source.index("\n return \"\"", start)
        completion = source[start:end]
        self.assertIn("var previous_best: float=best_seconds", completion)
        self.assertIn("var previous_runs: int=completed_runs", completion)
        self.assertIn("if persist and not save_record():", completion)
        failure = completion.split("if persist and not save_record():", 1)[1]
        self.assertLess(failure.index("best_seconds=previous_best"), failure.index("return \"ЭВАКУАЦИЯ"))
        self.assertLess(failure.index("completed_runs=previous_runs"), failure.index("return \"ЭВАКУАЦИЯ"))
        self.assertIn("phase=Phase.COMPLETE", completion)


if __name__ == "__main__":
    unittest.main()
