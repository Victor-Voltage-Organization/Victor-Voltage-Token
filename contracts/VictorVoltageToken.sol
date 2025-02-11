// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract VictorVoltageToken is ERC20, Ownable, ReentrancyGuard, Pausable {
    uint256 public constant TOTAL_SUPPLY = 170 * 10 ** 12 * 10 ** 18;
    uint256 public constant TRANSFER_TAX = 170;
    uint256 public constant BUY_SELL_TAX = 1700;

    uint256 public constant TITHING_TAX = 170;
    uint256 public constant BURN_TAX = 170;
    uint256 public constant REFLECTION_TAX = 170;
    uint256 public constant LP_INJECTION_TAX = 170;
    uint256 public constant TREASURY_TAX = 1020;

    address public treasuryWallet;
    address public lpWallet;
    address public tithingWallet;
    address public uniswapPair;

    uint256 public totalBurned;
    uint256 private _rTotal;
    uint256 private _tTotal;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 public maxTransactionAmount;

    event TaxesDistributed(
        uint256 tithingAmount,
        uint256 burnAmount,
        uint256 reflectionAmount,
        uint256 lpAmount,
        uint256 treasuryAmount
    );
    event WalletUpdated(string walletType, address newWallet);
    event UniswapPairSet(address newPair);

    constructor(
        address _treasuryWallet,
        address _lpWallet,
        address _tithingWallet
    ) ERC20("VictorVoltage", "V V") Ownable(msg.sender) {
        require(
            _treasuryWallet != address(0) &&
                _lpWallet != address(0) &&
                _tithingWallet != address(0),
            "Zero address not allowed"
        );

        treasuryWallet = _treasuryWallet;
        lpWallet = _lpWallet;
        tithingWallet = _tithingWallet;

        _rTotal = (type(uint256).max - (type(uint256).max % TOTAL_SUPPLY));
        _tTotal = TOTAL_SUPPLY;
        _rOwned[msg.sender] = _rTotal;

        _isExcludedFromFees[msg.sender] = true;
        _isExcludedFromFees[address(this)] = true;

        maxTransactionAmount = TOTAL_SUPPLY / 100; // 1% of total supply

        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override whenNotPaused {
        require(
            amount <= maxTransactionAmount,
            "Transfer amount exceeds the maxTransactionAmount."
        );

        uint256 taxAmount;
        if (_isExcludedFromFees[sender] || _isExcludedFromFees[recipient]) {
            taxAmount = 0;
        } else if (sender == uniswapPair || recipient == uniswapPair) {
            taxAmount = (amount * BUY_SELL_TAX) / 10000;
        } else {
            taxAmount = (amount * TRANSFER_TAX) / 10000;
        }

        _tokenTransfer(sender, recipient, amount, taxAmount);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 taxAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee
        ) = _getValues(tAmount, taxAmount);

        if (_rOwned[sender] < rAmount) {
            revert ERC20InsufficientBalance(sender, _rOwned[sender], rAmount);
        }
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _rOwned[address(this)] = _rOwned[address(this)] + rFee;

        if (_isExcluded[sender]) {
            _tOwned[sender] = _tOwned[sender] - tAmount;
            if (_tOwned[sender] < rAmount) {
                revert ERC20InsufficientBalance(
                    sender,
                    _tOwned[sender],
                    tAmount
                );
            }
        }
        if (_isExcluded[recipient]) {
            _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        }
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)] + tFee;
        }

        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);

        if (taxAmount > 0) {
            _distributeTaxes(taxAmount);
        }
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tTotal = _tTotal - tFee;
    }

    function _getValues(
        uint256 tAmount,
        uint256 taxAmount
    ) private view returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 tFee = taxAmount;
        uint256 tTransferAmount = tAmount - tFee;
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee;
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _distributeTaxes(uint256 taxAmount) private {
        uint256 tithingAmount = (taxAmount * TITHING_TAX) / BUY_SELL_TAX;
        uint256 burnAmount = (taxAmount * BURN_TAX) / BUY_SELL_TAX;
        uint256 reflectionAmount = (taxAmount * REFLECTION_TAX) / BUY_SELL_TAX;
        uint256 lpAmount = (taxAmount * LP_INJECTION_TAX) / BUY_SELL_TAX;
        // uint256 treasuryAmount = taxAmount * TREASURY_TAX / BUY_SELL_TAX;
        uint256 treasuryAmount = taxAmount -
            tithingAmount -
            burnAmount -
            reflectionAmount -
            lpAmount;

        _transfer(address(this), treasuryWallet, treasuryAmount);
        _transfer(address(this), lpWallet, lpAmount);
        _transfer(address(this), tithingWallet, tithingAmount);
        _burn(address(this), burnAmount);

        totalBurned += burnAmount;
        _tTotal -= burnAmount;

        emit TaxesDistributed(
            tithingAmount,
            burnAmount,
            reflectionAmount,
            lpAmount,
            treasuryAmount
        );
    }

    function setUniswapPair(address _uniswapPair) external onlyOwner {
        require(_uniswapPair != address(0), "Invalid Uniswap pair address");
        uniswapPair = _uniswapPair;
        emit UniswapPairSet(_uniswapPair);
    }

    function excludeFromFees(
        address account,
        bool excluded
    ) external onlyOwner {
        require(account != address(0), "Cannot exclude zero address");
        _isExcludedFromFees[account] = excluded;
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function updateTreasuryWallet(
        address newTreasuryWallet
    ) external onlyOwner {
        require(
            newTreasuryWallet != address(0),
            "New treasury wallet cannot be zero address"
        );
        treasuryWallet = newTreasuryWallet;
        emit WalletUpdated("Treasury Wallet", newTreasuryWallet);
    }

    function updateLpWallet(address newLpWallet) external onlyOwner {
        require(
            newLpWallet != address(0),
            "New LP wallet cannot be zero address"
        );
        lpWallet = newLpWallet;
        emit WalletUpdated("LP Wallet", newLpWallet);
    }

    function updateTithingWallet(address newTithingWallet) external onlyOwner {
        require(
            newTithingWallet != address(0),
            "New Tithing wallet cannot be zero address"
        );
        tithingWallet = newTithingWallet;
        emit WalletUpdated("Tithing Wallet", newTithingWallet);
    }

    function excludeFromReward(address account) external onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function setMaxTransactionAmount(uint256 amount) external onlyOwner {
        require(amount > 0 && amount <= TOTAL_SUPPLY / 10, "Invalid amount");
        maxTransactionAmount = amount;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
