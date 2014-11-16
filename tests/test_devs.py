import devs
import sys
import pytest


def test_infinity():
    assert devs.infinity == sys.float_info.max
