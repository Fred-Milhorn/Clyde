"""Clide: Augmented POSIX Usage -> argv parser for Python

Clide turns annotated `Usage:` lines into fully validated command-line parsers.
"""

from typing import List, Tuple, Callable
from .spec import Spec
from .parser import ParseError, from_lines
from .runtime import ArgError, ParseResult, choose_command, parse_with
from .help import render, render_with_docs


class Clide:
    """Main Clide API"""

    @staticmethod
    def from_usage_lines(usage: List[str]) -> Callable[[List[str]], ParseResult]:
        """Parse usage lines and return a parser function"""
        spec = from_lines(usage)

        def parse(argv: List[str]) -> ParseResult:
            cmd = choose_command(spec, argv)
            return parse_with(cmd, argv)

        return parse

    @staticmethod
    def help_of(usage: List[str]) -> str:
        """Render help text from usage lines"""
        spec = from_lines(usage)
        return render(spec)

    @staticmethod
    def help_with_docs(usage: List[str], docs: List[Tuple[str, str]]) -> str:
        """Render help text with user-provided documentation"""
        spec = from_lines(usage)
        return render_with_docs(spec, docs)


__all__ = ['Clide', 'ParseError', 'ArgError', 'ParseResult', 'Type']
