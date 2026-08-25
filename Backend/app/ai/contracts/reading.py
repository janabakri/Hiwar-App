from typing import Literal

from pydantic import Field, model_validator

from .base import StrictContract
from .memory import LearningCandidate


class TargetWord(StrictContract):
    word: str = Field(min_length=1, max_length=80)
    meaning_ar: str = Field(min_length=1, max_length=240)
    ipa: str = Field(max_length=120)
    example: str = Field(min_length=1, max_length=600)
    skill_code: str = Field(min_length=2, max_length=140)


class ReadingQuestion(StrictContract):
    id: str = Field(min_length=1, max_length=80)
    type: Literal["main_idea", "detail", "inference", "vocabulary"]
    question: str = Field(min_length=1, max_length=800)
    options: list[str] = Field(max_length=4)
    correct_answer: str = Field(min_length=1, max_length=1000)
    explanation_ar: str = Field(min_length=1, max_length=1200)

    @model_validator(mode="after")
    def validate_answer_key(self):
        if self.options and self.correct_answer not in self.options:
            raise ValueError("correct_answer must match one of the supplied options")
        return self


class ReadingLesson(StrictContract):
    title: str = Field(min_length=1, max_length=200)
    cefr_level: str = Field(min_length=2, max_length=10)
    topic: str = Field(min_length=1, max_length=120)
    passage: str = Field(min_length=40, max_length=5000)
    target_words: list[TargetWord] = Field(min_length=1, max_length=5)
    questions: list[ReadingQuestion] = Field(min_length=4, max_length=4)

    @model_validator(mode="after")
    def validate_question_set(self):
        ids = [item.id for item in self.questions]
        types = {item.type for item in self.questions}
        if len(set(ids)) != len(ids):
            raise ValueError("reading question ids must be unique")
        if types != {"main_idea", "detail", "inference", "vocabulary"}:
            raise ValueError("reading lesson must cover all four comprehension skills")
        return self


class PublicReadingQuestion(StrictContract):
    id: str
    type: Literal["main_idea", "detail", "inference", "vocabulary"]
    question: str
    options: list[str]


class PublicReadingLesson(StrictContract):
    title: str
    cefr_level: str
    topic: str
    passage: str
    target_words: list[TargetWord]
    questions: list[PublicReadingQuestion]

    @classmethod
    def from_lesson(cls, lesson: ReadingLesson) -> "PublicReadingLesson":
        return cls(
            title=lesson.title,
            cefr_level=lesson.cefr_level,
            topic=lesson.topic,
            passage=lesson.passage,
            target_words=lesson.target_words,
            questions=[
                PublicReadingQuestion(
                    id=item.id,
                    type=item.type,
                    question=item.question,
                    options=item.options,
                )
                for item in lesson.questions
            ],
        )


class ReadingAnswerAnalysis(StrictContract):
    correct: bool
    score: int = Field(ge=0, le=100)
    feedback_ar: str = Field(min_length=1, max_length=1200)
    evidence: str = Field(min_length=1, max_length=1500)
    memory_candidates: list[LearningCandidate] = Field(max_length=2)
    next_action: Literal["next_question", "show_hint", "finish"]


class ReadingSessionSummary(StrictContract):
    score: int = Field(ge=0, le=100)
    correct_answers: int = Field(ge=0)
    total_answers: int = Field(ge=0)
    strengths: list[str]
    review_focus: str
    next_activity: Literal["reading", "speaking", "review"]
    message_ar: str
