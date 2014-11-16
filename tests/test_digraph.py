import devs
import pytest


def test_digraph_creation_and_deletion():
    digraph = devs.Digraph()
    del digraph


def test_empty_list():
    digraph = devs.Digraph()

    assert len(list(digraph)) == 0


def test_add_model_memory_management():
    digraph = devs.Digraph()
    model = devs.AtomicBase()

    digraph.add(model)
    del digraph
    # This should not result in a Segmentation fault!
    del model


def test_add_model():
    digraph = devs.Digraph()
    model = devs.AtomicBase()

    digraph.add(model)
    assert len(list(digraph)) == 1
    assert list(digraph)[0] is model
