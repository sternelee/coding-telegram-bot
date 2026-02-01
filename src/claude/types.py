"""Shared type definitions for Claude Code integration.

This module contains common data structures used across different integration
methods (SDK and CLI subprocess) to avoid duplication.
"""

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class ClaudeResponse:
    """Response from Claude Code execution.

    Attributes:
        content: The text content of Claude's response
        session_id: Unique identifier for the session
        cost: Total cost in USD for this interaction
        duration_ms: Execution time in milliseconds
        num_turns: Number of conversation turns
        is_error: Whether this response represents an error
        error_type: Type of error if is_error is True
        tools_used: List of tools that were used during execution
    """

    content: str
    session_id: str
    cost: float
    duration_ms: int
    num_turns: int
    is_error: bool = False
    error_type: Optional[str] = None
    tools_used: List[Dict[str, Any]] = field(default_factory=list)


@dataclass
class StreamUpdate:
    """Streaming update from Claude Code during execution.

    Attributes:
        type: Update type ('assistant', 'user', 'system', 'result',
              'tool_result', 'error', 'progress')
        content: Text content of the update (if applicable)
        tool_calls: List of tool calls made (for assistant updates)
        metadata: Additional metadata about the update
        timestamp: When this update was generated
        session_context: Session information including session_id
        execution_id: Unique identifier for this execution
        parent_message_id: Parent message ID for threaded conversations
        error_info: Error details if this update represents an error
        progress: Progress information for progress-type updates
    """

    type: str  # 'assistant', 'user', 'system', 'result', 'tool_result', 'error', 'progress'
    content: Optional[str] = None
    tool_calls: Optional[List[Dict]] = None
    metadata: Optional[Dict] = None

    # Enhanced fields for better tracking
    timestamp: Optional[str] = None
    session_context: Optional[Dict] = None
    execution_id: Optional[str] = None
    parent_message_id: Optional[str] = None
    error_info: Optional[Dict] = None
    progress: Optional[Dict] = None

    def is_error(self) -> bool:
        """Check if this update represents an error."""
        return self.type == "error" or (
            self.metadata and self.metadata.get("is_error", False)
        )

    def get_error_message(self) -> Optional[str]:
        """Get error message if this is an error update."""
        if self.error_info:
            return self.error_info.get("message")
        if self.is_error() and self.content:
            return self.content
        return None

    def get_tool_names(self) -> List[str]:
        """Get list of tool names from tool_calls."""
        if not self.tool_calls:
            return []
        return [call.get("name", "unknown") for call in self.tool_calls if call.get("name")]

    def get_progress_percentage(self) -> Optional[int]:
        """Get progress percentage if available."""
        if self.progress:
            return self.progress.get("percentage")
        return None
