"""
Feedback Generator Module.

Generates actionable, human-readable vocal/instrument coaching feedback
based on pitch accuracy, note alignment, cents deviation, and stability scores.
"""

from typing import Dict, Any, List, Optional


class FeedbackGenerator:
    """
    Generates contextual feedback tips for vocal/instrument practice sessions.
    """

    def generate_feedback(
        self, score_data: Dict[str, Any], detected_notes: List[str]
    ) -> str:
        """
        Generate natural language coaching feedback string.
        
        Args:
            score_data: Dict containing 'accuracy_score', 'stability_score', etc.
            detected_notes: List of detected note strings.
            
        Returns:
            String feedback message.
        """
        accuracy = score_data.get("accuracy_score", 0)
        stability = score_data.get("stability_score", 0.0)

        if accuracy >= 90:
            summary = f"Outstanding performance! Excellent pitch accuracy ({accuracy}%) and rock-solid intonation."
        elif accuracy >= 75:
            summary = f"Great job! Your overall pitch accuracy is {accuracy}%. Keep focusing on smooth breath control to boost stability."
        elif accuracy >= 50:
            summary = f"Good effort! Pitch accuracy reached {accuracy}%. Try practicing at a slower tempo to perfect note alignment."
        else:
            summary = "Keep practicing! Focus on sustaining single notes clearly into the microphone to build pitch memory."

        # Include specific note feedback if note_evaluations are available
        evaluations = score_data.get("note_evaluations", [])
        if evaluations:
            corrections = []
            for ev in evaluations:
                if ev.get("status") == "incorrect":
                    corrections.append(f"Sung {ev.get('detected')} instead of target {ev.get('target')}")
                elif ev.get("status") == "missed":
                    corrections.append(f"Missed target {ev.get('target')}")

            if corrections:
                summary += " Note adjustments needed: " + "; ".join(corrections[:3]) + "."

        return summary

    def generate_detailed_feedback(
        self, score_data: Dict[str, Any], analysis_result: Optional[Dict[str, Any]] = None
    ) -> List[str]:
        """
        Generate structured, actionable feedback bullet points.
        
        Returns:
            List of string coaching tips and diagnostic bullet points.
        """
        tips: List[str] = []
        accuracy = score_data.get("accuracy_score", 0)
        note_acc = score_data.get("note_accuracy", accuracy)
        pitch_acc = score_data.get("pitch_accuracy", accuracy)
        stability = score_data.get("stability_score", 8.5)
        evaluations = score_data.get("note_evaluations", [])

        # 1. Pitch & Note Accuracy Feedback
        correct_notes = [ev["target"] for ev in evaluations if ev.get("matched")]
        incorrect_notes = [ev for ev in evaluations if ev.get("status") == "incorrect"]
        missed_notes = [ev["target"] for ev in evaluations if ev.get("status") == "missed"]

        if correct_notes:
            tips.append(f"Accurate pitch hold on notes: {', '.join(correct_notes)}.")

        if incorrect_notes:
            for inc in incorrect_notes[:3]:
                t = inc.get("target")
                d = inc.get("detected")
                tips.append(f"Pitch mismatch: Detected {d} when target was {t}. Focus on clean intervals.")

        if missed_notes:
            tips.append(f"Target notes missed: {', '.join(missed_notes)}. Ensure you sustain each note through its full duration.")

        # 2. Intonation & Cents Drift
        if analysis_result and "cents_deviations" in analysis_result:
            cents = analysis_result["cents_deviations"]
            if cents:
                mean_cents = sum(cents) / len(cents)
                if mean_cents > 15:
                    tips.append(f"Tendency to sing slightly sharp (+{mean_cents:.1f} cents on average). Relax throat tension.")
                elif mean_cents < -15:
                    tips.append(f"Tendency to sing slightly flat ({mean_cents:.1f} cents on average). Engage diaphragm support.")

        # 3. Stability & Breath Support
        if stability >= 8.5:
            tips.append(f"Vocal stability is strong ({stability}/10.0) with minimal pitch wobble.")
        elif stability >= 6.5:
            tips.append(f"Moderate vocal stability ({stability}/10.0). Focus on steady breath flow to eliminate pitch flutter.")
        else:
            tips.append(f"Vocal stability needs attention ({stability}/10.0). Practice long sustained tones with steady abdominal support.")

        # 4. Overall summary tip
        if not tips:
            tips.append(self.generate_feedback(score_data, []))

        return tips
