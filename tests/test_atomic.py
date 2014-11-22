import devs
import pytest


def test_creation_and_deletion():
    model = devs.AtomicBase()
    del model
