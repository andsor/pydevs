import sys

import pydevs
import pytest


def test_infinity():
    assert pydevs.infinity == sys.float_info.max
