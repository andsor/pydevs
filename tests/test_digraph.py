import devs
import pytest


@pytest.fixture
def digraph():
    return devs.Digraph()


def test_digraph_creation_and_deletion(digraph):
    del digraph


def test_empty_list(digraph):
    assert len(list(digraph)) == 0


def test_add_model_memory_management(digraph):
    model = devs.AtomicBase()

    digraph.add(model)
    del digraph
    # This should not result in a Segmentation fault!
    del model


def test_add_model(digraph):
    model = devs.AtomicBase()

    digraph.add(model)
    assert len(list(digraph)) == 1
    assert list(digraph)[0] is model


def test_add_and_couple_two_models(digraph):
    models = [ devs.AtomicBase() for _ in range(2) ]
    for model in models:
        digraph.add(model)

    digraph.couple(models[0], 1, models[1], 2)
