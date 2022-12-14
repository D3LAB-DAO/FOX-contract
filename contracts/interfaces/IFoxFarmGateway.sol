// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IFoxFarmGateway {
    //============ View Functions (Mint) ============//

    function defaultValuesMint(
        address account_,
        uint256 id_
    )
        external
        view
        returns (
            uint256 collateralAmount_,
            uint256 ltv_,
            uint256 shareAmount_,
            uint256 stableAmount_
        );

    function ltvRangeWhenMint(
        uint256 id_,
        uint256 collateralAmount_,
        uint256 shareAmount_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function collateralAmountRangeWhenMint(
        address account_,
        uint256 id_,
        uint256 ltv_,
        uint256 shareAmount_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function shareAmountRangeWhenMint(
        address account_,
        uint256 id_,
        uint256 collateralAmount_,
        uint256 ltv_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function requiredShareAmountFromCollateralToLtv(
        uint256 id_,
        uint256 newCollateralAmount_,
        uint256 ltv_
    ) external view returns (uint256 shareAmount_);

    function requiredCollateralAmountFromShareToLtv(
        uint256 id_,
        uint256 newShareAmount_,
        uint256 ltv_
    ) external view returns (uint256 collateralAmount_);

    function expectedMintAmountToLtv(
        uint256 id_,
        uint256 newCollateralAmount_,
        uint256 ltv_,
        uint256 newShareAmount_
    ) external view returns (uint256 newStableAmount_);

    //============ View Functions (Redeem) ============//

    function defaultValueRedeem(
        address account_,
        uint256 id_
    )
        external
        view
        returns (
            uint256 stableAmount_,
            uint256 collateralAmount_,
            uint256 ltv_,
            uint256 shareAmount_
        );

    function ltvRangeWhenRedeem(
        uint256 id_,
        uint256 collectedStableAmount_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function stableAmountRangeWhenRedeem(
        address account_,
        uint256 id_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function expectedRedeemAmountToLtv(
        uint256 id_,
        uint256 collectedStableAmount_,
        uint256 ltv_
    )
        external
        view
        returns (uint256 emittedCollateralAmount_, uint256 emittedShareAmount_);

    //============ View Functions (Recoll) ============//

    function defaultValuesRecollateralize(
        address account_,
        uint256 id_
    )
        external
        view
        returns (uint256 collateralAmount_, uint256 ltv_, uint256 shareAmount_);

    function ltvRangeWhenRecollateralize(
        uint256 id_,
        uint256 collateralAmount_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function collateralAmountRangeWhenRecollateralize(
        address account_,
        uint256 id_,
        uint256 ltv_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function exchangedShareAmountFromCollateralToLtv(
        uint256 id_,
        uint256 collateralAmount_,
        uint256 ltv_
    ) external view returns (uint256 shareAmount_);

    //============ View Functions (Buyback) ============//

    function defaultValuesBuyback(
        address account_,
        uint256 id_
    )
        external
        view
        returns (uint256 shareAmount_, uint256 collateralAmount_, uint256 ltv_);

    function ltvRangeWhenBuyback(
        uint256 id_,
        uint256 shareAmount_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function shareAmountRangeWhenBuyback(
        address account_,
        uint256 id_
    ) external view returns (uint256 upperBound_, uint256 lowerBound_);

    function exchangedCollateralAmountFromShareToLtv(
        uint256 id_,
        uint256 shareAmount_,
        uint256 ltv_
    ) external view returns (uint256 collateralAmount_);

    //============ View Functions (Coupon) ============//
}
