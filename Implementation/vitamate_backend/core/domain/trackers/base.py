from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class TrackerStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    DISABLED = "disabled"


@dataclass(frozen=True)
class TrackerGoal:
    name: str
    target_value: float
    unit: str


@dataclass(frozen=True)
class TrackerSnapshot:
    tracker_id: str
    status: TrackerStatus
    current_value: float
    goal: TrackerGoal | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class BaseTracker(ABC):
    """Domain abstraction that normalizes different tracker shapes."""

    @abstractmethod
    def snapshot(self) -> TrackerSnapshot:
        raise NotImplementedError

