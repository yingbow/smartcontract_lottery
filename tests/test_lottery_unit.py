# based on ETH value of USD$3309.33/ETH, for $50, we expect to get ~0.015 ETH
# In wei, that will be 15000000000000000

from brownie import Lottery, accounts, network, config, exceptions
from scripts.deploy_lottery import deploy_lottery

from web3 import Web3
import pytest

from scripts.helpful_scripts import (
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    get_account,
    fund_with_link,
    get_contract,
)


def test_get_entrace_fee():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    # Arrange
    lottery = deploy_lottery()
    # Act
    # If price of ETH is USD$2000/ETH, and usdEntryFee is USD50
    # Then expected eth is 50/2000 = 0.016
    expected_entrance_fee = Web3.toWei(0.025, "ether")
    entrance_fee = lottery.getEntranceFee()
    # Assert
    assert expected_entrance_fee == entrance_fee


def test_cant_enter_unless_started():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    lottery = deploy_lottery()
    # Act/Assert
    with pytest.raises(exceptions.VirtualMachineError):
        lottery.enter({"from": get_account(), "value": lottery.getEntranceFee()})


def test_can_start_and_enter_lottery():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    lottery = deploy_lottery()
    account = get_account()
    lottery.startLottery({"from": account})
    # Act
    lottery.enter({"from": account, "value": lottery.getEntranceFee()})
    # Assert
    assert lottery.players(0) == account


def test_can_end_lottery():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    lottery = deploy_lottery()
    account = get_account()
    lottery.startLottery({"from": account})
    lottery.enter({"from": account, "value": lottery.getEntranceFee()})
    fund_with_link(lottery)
    lottery.endLottery({"from": account})
    # Assert
    assert lottery.lottery_state() == 2  # check if lottery state is CALCULATING_WINNER


def test_can_pick_winner_correctly():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    lottery = deploy_lottery()
    account = get_account()
    lottery.startLottery({"from": account})
    # entrant 1
    lottery.enter({"from": account, "value": lottery.getEntranceFee()})
    # entrant 2
    lottery.enter({"from": get_account(index=1), "value": lottery.getEntranceFee()})
    # entrant 3
    lottery.enter({"from": get_account(index=2), "value": lottery.getEntranceFee()})
    fund_with_link(lottery)
    transaction = lottery.endLottery({"from": account})
    # events attribute of lottery object1
    request_id = transaction.events["RequestedRandomness"]["requestId"]
    STATIC_RNG = 777
    # dummy-ing get a response from a chainlink node
    get_contract("vrf_coordinator").callBackWithRandomness(
        request_id, STATIC_RNG, lottery.address, {"from": account}
    )
    starting_balance_of_account = account.balance()
    balance_of_lottery = lottery.balance()
    # Random number % no. of players = 777 % 3 = 0
    # Hence, in this particular setting, assert that entrant 1 is the winner
    assert lottery.recentWinner() == account
    # assert that lottery is now empty (no $$)
    assert lottery.balance() == 0
    # assert that winner's account now has the lottery $$ added to it
    assert account.balance() == starting_balance_of_account + balance_of_lottery
