import pydevs
import pytest


def test_creation_and_deletion():
    model = pydevs.AtomicBase()
    del model
