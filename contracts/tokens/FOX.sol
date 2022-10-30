// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../oracle/Oracle.sol";
import "../utils/Allowlist.sol";
import "../utils/Interval.sol";
import "../utils/Nonzero.sol";
import "../interfaces/IFOXS.sol";

import "../interfaces/IFOX.sol";

/**
 * @title Fractional Over Collateralized Stablecoin (FOX)
 * @author Luke Park (lukepark327@gmail.com)
 * @notice Gets SIN and FOXS, gives FOX as debt.
 */
contract FOX is
    IFOX,
    Oracle,
    Allowlist,
    Interval,
    Nonzero,
    ERC20,
    Pausable,
    Ownable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20;

    //============ Params ============//

    IERC20 private immutable _debtToken;
    IERC20 private immutable _shareToken;

    uint256 private constant _TARGET_PRICE = 10000; // $1
    uint256 private _stablePrice = _TARGET_PRICE;
    uint256 private _sharePrice = _TARGET_PRICE; // TODO: initial share price
    // treats SIN and Stablecoin are always $1.

    uint256 private constant _DENOMINATOR = 10000;
    uint256 private constant _BABY_STEP = 25; // 0.25%
    uint256 private constant _BIG_STEP = _BABY_STEP * 2; // 0.50%
    uint256 private constant _GIANT_STEP = _BABY_STEP * 3; // 0.75%
    uint256 private constant _ULTRA_STEP = _BABY_STEP * 4; // 1.00%
    uint256 public step;

    uint256 private constant _TIME_PERIOD = 1 hours;
    uint256 public trustLevel = 0; // 0 ~ 10000 (0% ~ 100%)

    address private _feeTo;
    uint256 private _mintFeeRatio; // (feeRatio / _DENOMINATOR)
    uint256 private _burnFeeRatio; // (feeRatio / _DENOMINATOR)

    uint256 private _bonusRatio; // recollateralization bonus

    //============ Initialize ============//

    constructor(
        address oracleFeeder_,
        address feeTo_,
        address debtToken_,
        address shareToken_,
        uint256 mintFeeRatio_, // 20 as default
        uint256 burnFeeRatio_, // 45 as default
        uint256 bonusRatio_ // 75 as default
    )
        ERC20("Fractional Over Collateralized Stablecoin", "FOX")
        nonzeroAddress(oracleFeeder_)
        Oracle(oracleFeeder_)
        nonzeroAddress(debtToken_)
        nonzeroAddress(shareToken_)
    {
        _feeTo = feeTo_; // can be zero address
        _debtToken = IERC20(debtToken_);
        _shareToken = IFOXS(shareToken_);

        step = _ULTRA_STEP;

        _mintFeeRatio = mintFeeRatio_;
        _burnFeeRatio = burnFeeRatio_;

        _bonusRatio = bonusRatio_;
    }

    //============ Owner ============//

    function setFeeTo(address newFeeTo) external onlyOwner {
        address prevFeeTo = _feeTo;
        _feeTo = newFeeTo;
        emit SetFeeTo(prevFeeTo, _feeTo);
    }

    function setMintFeeRatio(uint256 newMintFeeRatio) external onlyOwner {
        uint256 prevMintFeeRatio = _mintFeeRatio;
        _mintFeeRatio = newMintFeeRatio;
        emit SetMintFeeRatio(prevMintFeeRatio, _mintFeeRatio);
    }

    function setBurnFeeRatio(uint256 newBunrFeeRatio) external onlyOwner {
        uint256 prevBunrFeeRatio = _burnFeeRatio;
        _burnFeeRatio = newBunrFeeRatio;
        emit SetBurnFeeRatio(prevBunrFeeRatio, _burnFeeRatio);
    }

    function setBonusRatio(uint256 newBonusRatio) external onlyOwner {
        uint256 prevBonusRatio = _bonusRatio;
        _bonusRatio = newBonusRatio;
        emit SetBonusRatio(prevBonusRatio, _bonusRatio);
    }

    function addAllowlist(address newAddr) external onlyOwner {
        _addAllowlist(newAddr);
    }

    function removeAllowlist(address targetAddr) external onlyOwner {
        _removeAllowlist(targetAddr);
    }

    function setAllowAll(bool newAllowAll) external onlyOwner {
        _setAllowAll(newAllowAll);
    }

    //============ Pausable ============//

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    //============ Oracle Functions ============//

    function updateOracleFeeder(address newOracleFeeder) external onlyOwner {
        _updateOracleFeeder(newOracleFeeder);
    }

    function updateStablePrice(uint256 newStablePrice, uint256 confidence)
        external
        onlyOracleFeeder
    {
        // TODO: confidence interval, delta -> pause

        uint256 prevPrice = _stablePrice;
        _stablePrice = newStablePrice;
        emit UpdatePrice(address(this), prevPrice, _stablePrice);
    }

    function updateStablePriceWithTrustLevel(
        uint256 newStablePrice,
        uint256 confidence
    ) external onlyOracleFeeder {
        // TODO: confidence interval, delta -> pause

        uint256 prevPrice = _stablePrice;
        _stablePrice = newStablePrice;
        emit UpdatePrice(address(this), prevPrice, _stablePrice);

        _updateTrustLevel();
    }

    function updateSharePrice(uint256 newSharePrice, uint256 confidence)
        external
        onlyOracleFeeder
    {
        // TODO: confidence interval, delta -> pause

        uint256 prevPrice = _sharePrice;
        _sharePrice = newSharePrice;
        emit UpdatePrice(address(_shareToken), prevPrice, _stablePrice);
    }

    //============ Trust-related Functions ============//

    function updateTrustLevel() external onlyOwner {
        _updateTrustLevel();
    }

    function _updateTrustLevel() internal interval(_TIME_PERIOD) {
        if (deltaTrust() < 0) {
            trustLevel -= step;
        } else {
            trustLevel += step;
        }
    }

    function updateStep(Step step_) external onlyOwner {
        if (step_ == Step.baby) {
            step = _BABY_STEP;
        } else if (step_ == Step.big) {
            step = _BIG_STEP;
        } else if (step_ == Step.giant) {
            step = _GIANT_STEP;
        } else if (step_ == Step.ultra) {
            step = _ULTRA_STEP;
        } else {
            revert("FOX::updateStep: Not a valid step.");
        }
    }

    //============ View Functions ============//

    function getStablePrice() external view onlyAllowlist returns (uint256) {
        return _stablePrice;
    }

    function getSharePrice() external view onlyAllowlist returns (uint256) {
        return _sharePrice;
    }

    function currentTrustLevel() public view returns (uint256) {
        return
            (_debtToken.balanceOf(address(this)) * _DENOMINATOR) /
            totalSupply();
    }

    /**
     * @notice Returns error of stablecoin price.
     * @dev Over-trusted when `deltaTrust()` > 0.
     * Under-trusted when `deltaTrust()` < 0.
     * Neutal-trusted when `deltaTrust()` == 0.
     */
    function deltaTrust() public view returns (int256) {
        return int256(_stablePrice - _TARGET_PRICE);
    }

    function deltaTrustLevel() public view returns (int256) {
        return int256(currentTrustLevel() - trustLevel);
    }

    function requiredShareAmountFromDebt(uint256 debtAmount_)
        public
        view
        returns (uint256)
    {
        return
            (debtAmount_ * trustLevel * _DENOMINATOR) /
            ((_DENOMINATOR - trustLevel) * _sharePrice);
    }

    function requiredShareAmountFromStable(uint256 stableAmount_)
        public
        view
        returns (uint256)
    {
        return (stableAmount_ * trustLevel) / (_sharePrice);
    }

    function requiredDebtAmountFromShare(uint256 shareAmount_)
        public
        view
        returns (uint256)
    {
        return (shareAmount_ * _sharePrice) / trustLevel;
    }

    function requiredDebtAmountFromStable(uint256 stableAmount_)
        public
        view
        returns (uint256)
    {
        return (stableAmount_ * (_DENOMINATOR - trustLevel)) / (_DENOMINATOR);
    }

    function expectedMintAmount(uint256 debtAmount_, uint256 shareAmount_)
        public
        view
        returns (uint256 stableAmount_)
    {
        // calculate min amount to mint
        uint256 _requiredDebtAmount;
        uint256 _requiredShareAmount = requiredShareAmountFromDebt(debtAmount_);
        if (_requiredShareAmount > shareAmount_) {
            _requiredDebtAmount = requiredDebtAmountFromShare(shareAmount_);
            require(
                _requiredDebtAmount <= debtAmount_,
                "FOX::_mintInternal: Not enough debtTokens."
            );
            _requiredShareAmount = shareAmount_;
        } else {
            _requiredDebtAmount = debtAmount_;
        }

        stableAmount_ =
            _requiredDebtAmount +
            (_requiredShareAmount * _sharePrice) /
            _DENOMINATOR;
    }

    function expectedRedeemAmount(uint256 stableAmount_)
        public
        view
        returns (uint256 debtAmount_, uint256 shareAmount_)
    {
        debtAmount_ = requiredDebtAmountFromStable(stableAmount_);
        shareAmount_ = requiredShareAmountFromStable(stableAmount_);
    }

    function shortfallRecollateralizeAmount()
        public
        view
        returns (uint256 debtAmount_)
    {
        return
            (totalSupply() * (_DENOMINATOR - trustLevel)) /
            _DENOMINATOR -
            _debtToken.balanceOf(address(this));
    }

    function surplusBuybackAmount() public view returns (uint256 debtAmount_) {
        return
            _debtToken.balanceOf(address(this)) -
            (totalSupply() * (_DENOMINATOR - trustLevel)) /
            _DENOMINATOR;
    }

    function exchangedShareAmountFromDebt(uint256 debtAmount_)
        public
        view
        returns (uint256 shareAmount_)
    {
        shareAmount_ = (debtAmount_ * _DENOMINATOR) / (_sharePrice);
    }

    function exchangedDebtAmountFromShare(uint256 shareAmount_)
        public
        view
        returns (uint256 debtAmount_)
    {
        debtAmount_ = (shareAmount_ * _sharePrice) / _DENOMINATOR;
    }

    //============ Mint & Redeem ============//

    function mint(
        address toAccount_,
        uint256 debtAmount_,
        uint256 shareAmount_
    ) external whenNotPaused returns (uint256 stableAmount_) {
        address _fromAccount = _msgSender();

        // send
        _debtToken.safeTransferFrom(_fromAccount, address(this), debtAmount_);
        _shareToken.safeTransferFrom(_fromAccount, address(this), shareAmount_);

        // calculate
        stableAmount_ = expectedMintAmount(debtAmount_, shareAmount_);

        // receive
        uint256 _fee = (stableAmount_ * _mintFeeRatio) / _DENOMINATOR;
        if (_feeTo != address(0)) {
            _mint(_feeTo, _fee);
            _mint(toAccount_, stableAmount_ - _fee);
        } else {
            _mint(toAccount_, stableAmount_);
        }
    }

    function redeem(address toAccount_, uint256 stableAmount_)
        external
        whenNotPaused
        returns (uint256 debtAmount_, uint256 shareAmount_)
    {
        address _fromAccount = _msgSender();

        // send
        _burn(_fromAccount, stableAmount_);

        // calculate
        (debtAmount_, shareAmount_) = expectedRedeemAmount(stableAmount_);

        // receive
        if (_feeTo != address(0)) {
            _debtToken.safeTransferFrom(
                address(this),
                toAccount_,
                debtAmount_ - (debtAmount_ * _burnFeeRatio) / _DENOMINATOR // _feeTo
            );
            _shareToken.safeTransferFrom(
                address(this),
                toAccount_,
                shareAmount_ - (shareAmount_ * _burnFeeRatio) / _DENOMINATOR // _feeTo
            );
        } else {
            _debtToken.safeTransferFrom(address(this), toAccount_, debtAmount_);
            _shareToken.safeTransferFrom(
                address(this),
                toAccount_,
                shareAmount_
            );
        }
    }

    //============ Recallateralize & Buyback ============//

    function recollateralize(address toAccount_, uint256 debtAmount_)
        external
        whenNotPaused
        returns (uint256 shareAmount_, uint256 bonusAmount_)
    {
        uint256 _shortfallAmount = shortfallRecollateralizeAmount(); // also checks recollateralizing condition
        _shortfallAmount = _shortfallAmount >= debtAmount_
            ? debtAmount_
            : _shortfallAmount;

        // send
        _debtToken.safeTransferFrom(
            _msgSender(),
            address(this),
            _shortfallAmount
        );

        // calculate
        shareAmount_ = exchangedShareAmountFromDebt(_shortfallAmount);
        bonusAmount_ = (shareAmount_ * _bonusRatio) / _DENOMINATOR;

        // receive
        _shareToken.safeTransfer(toAccount_, shareAmount_);
        IFOXS(address(_shareToken)).mint(toAccount_, shareAmount_);
    }

    function buyback(address toAccount_, uint256 shareAmount_)
        external
        whenNotPaused
        returns (uint256 debtAmount_)
    {
        uint256 _surplusAmount = surplusBuybackAmount(); // also checks recollateralizing condition
        uint256 _exchangedSurplusShareAmount = exchangedShareAmountFromDebt(
            _surplusAmount
        );
        _exchangedSurplusShareAmount = _exchangedSurplusShareAmount >=
            shareAmount_
            ? shareAmount_
            : _exchangedSurplusShareAmount;

        // send
        _shareToken.safeTransferFrom(
            _msgSender(),
            address(this),
            _exchangedSurplusShareAmount
        );

        // calculate
        debtAmount_ = exchangedDebtAmountFromShare(
            _exchangedSurplusShareAmount
        );

        // receive
        _debtToken.safeTransfer(toAccount_, debtAmount_);
    }

    // TODO: can get surplus FOXS
    function skim(address toAccount_)
        external
        whenNotPaused
        returns (uint256 shareAmount_)
    {

    }

    //============ ERC20-related Functions ============//

    function approveMax(address spender) public {
        _approve(_msgSender(), spender, type(uint256).max);
    }
}
