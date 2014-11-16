import devs
import pytest


class TestAtomic(devs.AtomicBase):
    def delta_int(self):
        pass

    def delta_ext(self, e, xb):
        pass

    def delta_conf(self, xb):
        pass

    def output_func(self, yb):
        pass

    def ta(self):
        return devs.infinity


@pytest.fixture
def atomic():
    return TestAtomic()


@pytest.fixture
def digraph():
    return devs.Digraph()


@pytest.fixture
def digraph_one_model(digraph, atomic):
    digraph.add(atomic)
    return digraph


@pytest.fixture
def digraph_two_models(digraph):
    for _ in range(2):
        digraph.add(TestAtomic())
    return digraph


def test_add_atomic_base_model_fails():
    model = devs.AtomicBase()

    with pytest.raises(TypeError):
        devs.Simulator(model)


def test_add_atomic_model(atomic):
    devs.Simulator(atomic)


def test_atomic_no_event(atomic):
    simulator = devs.Simulator(atomic)
    assert simulator.next_event_time() == devs.infinity


def test_atomic_next_event_time(atomic, mocker):
    mocker.patch.object(atomic, 'ta', return_value=1.0)
    simulator = devs.Simulator(atomic)
    assert simulator.next_event_time() == 1.0


def test_add_digraph(digraph):
    devs.Simulator(digraph)


def test_add_digraph_with_one_model(digraph_one_model):
    devs.Simulator(digraph_one_model)


def test_digraph_with_one_model_no_event(digraph_one_model):
    model = list(digraph_one_model)[0]
    simulator = devs.Simulator(digraph_one_model)
    assert simulator.next_event_time() == devs.infinity


def test_digraph_with_one_model_next_event_time(digraph_one_model, mocker):
    model = list(digraph_one_model)[0]
    mocker.patch.object(model, 'ta', return_value=1.0)
    simulator = devs.Simulator(digraph_one_model)
    assert simulator.next_event_time() == 1.0


def test_digraph_with_two_models(digraph_two_models):
    models = list(digraph_two_models)
    assert len(models) == 2


def test_add_digraph_with_two_models_no_event(digraph_two_models):
    models = list(digraph_two_models)
    simulator = devs.Simulator(digraph_two_models)
    assert simulator.next_event_time() == devs.infinity


def test_add_digraph_with_two_models_next_event_time(
    digraph_two_models, mocker
):
    models = list(digraph_two_models)
    mocker.patch.object(models[1], 'ta', return_value=1.0)
    simulator = devs.Simulator(digraph_two_models)
    assert simulator.next_event_time() == 1.0


def test_atomic_execute_next_event_at_infinity_does_not_delta_int(
    atomic, mocker
):
    delta_int = mocker.patch.object(atomic, 'delta_int')
    simulator = devs.Simulator(atomic)
    simulator.execute_next_event()
    assert not delta_int.called


def test_atomic_execute_next_event(atomic, mocker):
    mocker.patch.object(atomic, 'ta', return_value=1.0)
    devs_func = {
        func: mocker.patch.object(atomic, func)
        for func in ['delta_int', 'delta_ext', 'delta_conf', 'output_func']
    }
    simulator = devs.Simulator(atomic)
    simulator.execute_next_event()
    assert devs_func['delta_int'].call_count == 1
    assert devs_func['output_func'].call_count == 1
    assert not devs_func['delta_ext'].called
    assert not devs_func['delta_conf'].called
    assert simulator.next_event_time() == 2.0


def test_digraph_execute_next_event(digraph):
    simulator = devs.Simulator(digraph)
    simulator.execute_next_event()
    assert simulator.next_event_time() == devs.infinity


def test_digraph_one_model_execute_next_event_at_infinity(
    digraph_one_model, mocker
):
    model = list(digraph_one_model)[0]
    delta_int = mocker.patch.object(model, 'delta_int')
    simulator = devs.Simulator(digraph_one_model)
    simulator.execute_next_event()
    assert not delta_int.called


def test_digraph_one_model_execute_next_event(digraph_one_model, mocker):
    model = list(digraph_one_model)[0]
    mocker.patch.object(model, 'ta', return_value=1.0)
    devs_func = {
        func: mocker.patch.object(model, func)
        for func in ['delta_int', 'delta_ext', 'delta_conf', 'output_func']
    }
    simulator = devs.Simulator(model)
    simulator.execute_next_event()
    assert devs_func['delta_int'].call_count == 1
    assert devs_func['output_func'].call_count == 1
    assert not devs_func['delta_ext'].called
    assert not devs_func['delta_conf'].called
    assert simulator.next_event_time() == 2.0


def test_digraph_two_models_execute_next_event(digraph_two_models, mocker):
    models = list(digraph_two_models)
    for model, ta in zip(models, [1.0, 1.2]):
        mocker.patch.object(model, 'ta', return_value=ta)
    delta_ints = [
        mocker.patch.object(model, 'delta_int')
        for model in models
    ]
    simulator = devs.Simulator(digraph_two_models)
    assert not delta_ints[0].called
    simulator.execute_next_event()
    assert delta_ints[0].call_count == 1
    assert not delta_ints[1].called
    simulator.execute_next_event()
    assert delta_ints[0].call_count == 1
    assert delta_ints[1].call_count == 1
    assert simulator.next_event_time() == 2.0
