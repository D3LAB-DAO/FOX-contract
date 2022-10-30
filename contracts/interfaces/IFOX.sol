// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IFOX {
    //============ Params ============//

    enum Step {
        baby,
        big,
        giant,
        ultra
    }

    //============ Events ============//

    event SetFeeTo(address prevFeeTo, address currFeeTo);
    event SetMintFeeRatio(uint256 prevMintFeeRatio, uint256 currMintFeeRatio);
    event SetBurnFeeRatio(uint256 prevBurnFeeRatio, uint256 currBurnFeeRatio);
    event SetBonusRatio(uint256 prevBonusRatio, uint256 currBonusRatio);

    //============ Owner ============//

    function setFeeTo(address newFeeTo) external;

    function setMintFeeRatio(uint256 newMintFeeRatio) external;

    function setBurnFeeRatio(uint256 newBunrFeeRatio) external;

    function setBonusRatio(uint256 newBonusRatio) external;

    function addAllowlist(address newAddr) external;

    function removeAllowlist(address targetAddr) external;

    function setAllowAll(bool newAllowAll) external;

    //============ Pausable ============//

    function pause() external;

    function unpause() external;

    //============ Oracle Functions ============//

    function updateOracleFeeder(address newOracleFeeder) external;

    function updateStablePrice(uint256 newStablePrice, uint256 confidence)
        external;

    function updateStablePriceWithTrustLevel(
        uint256 newStablePrice,
        uint256 confidence
    ) external;

    function updateSharePrice(uint256 newSharePrice, uint256 confidence)
        external;

    //============ Trust-related Functions ============//

    function updateTrustLevel() external;

    function updateStep(Step step_) external;

    //============ View Functions ============//
    function getStablePrice() external view returns (uint256);

    function getSharePrice() external view returns (uint256);

    function currentTrustLevel() external view returns (uint256);

    function deltaTrust() external view returns (int256);

    function deltaTrustLevel() external view returns (int256);

    function requiredShareAmountFromDebt(uint256 debtAmount_)
        external
        view
        returns (uint256);

    function requiredShareAmountFromStable(uint256 stableAmount_)
        external
        view
        returns (uint256);

    function requiredDebtAmountFromShare(uint256 shareAmount_)
        external
        view
        returns (uint256);

    function requiredDebtAmountFromStable(uint256 stableAmount_)
        external
        view
        returns (uint256);

    function expectedMintAmount(uint256 debtAmount_, uint256 shareAmount_)
        external
        view
        returns (uint256 stableAmount_);

    function expectedRedeemAmount(uint256 stableAmount_)
        external
        view
        returns (uint256 debtAmount_, uint256 shareAmount_);

    function shortfallRecollateralizeAmount()
        external
        view
        returns (uint256 debtAmount_);

    function surplusBuybackAmount() external view returns (uint256 debtAmount_);

    function exchangedShareAmountFromDebt(uint256 debtAmount_)
        external
        view
        returns (uint256 shareAmount_);

    function exchangedDebtAmountFromShare(uint256 shareAmount_)
        external
        view
        returns (uint256 debtAmount_);

    //============ Mint & Redeem ============//

    function mint(
        address toAccount_,
        uint256 debtAmount_,
        uint256 shareAmount_
    ) external returns (uint256 stableAmount_);

    function redeem(address toAccount_, uint256 stableAmount_)
        external
        returns (uint256 debtAmount_, uint256 shareAmount_);

    //============ Recallateralize & Buyback ============//

    function recollateralize(address toAccount_, uint256 debtAmount_)
        external
        returns (uint256 shareAmount_, uint256 bonusAmount_);

    function buyback(address toAccount_, uint256 shareAmount_)
        external
        returns (uint256 debtAmount_);

    //============ ERC20-related Functions ============//

    function approveMax(address spender) external;
}
