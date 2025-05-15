// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title  VictorVoltage (V V) – Reflective Tax Token
/// @notice 1.7% transfer tax / 17% buy-sell tax, split into tithing, burn, reflection, LP, treasury.
/// @dev Uses basis-points (bps) for all rates; pins to latest Solidity release.
contract VictorVoltageToken is ERC20, Ownable, Pausable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant INITIAL_SUPPLY    = 170 * 10**12 * 10**18;
    uint16  public constant TRANSFER_TAX_BPS  = 170;   // 1.7%
    uint16  public constant TRADE_TAX_BPS     = 1700;  // 17%

    // breakdown of TRADE_TAX_BPS (bps relative to TRADE_TAX_BPS)
    uint16 private constant TITHING_BPS      = 170;   // 1.7%
    uint16 private constant BURN_BPS         = 170;   // 1.7%
    uint16 private constant REFLECTION_BPS   = 170;   // 1.7%
    uint16 private constant LP_BPS           = 170;   // 1.7%
    uint16 private constant TREASURY_BPS     = 1020;  // 10.2%

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public treasuryWallet;
    address public lpWallet;
    address public tithingWallet;
    address public uniswapPair;
    uint256 public maxTxAmount;

    // reflection bookkeeping
    uint256 private _rTotal;
    uint256 private _tTotal;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => bool)    private _isExcludedFromFee;
    mapping(address => bool)    private _isExcludedFromReward;
    address[]                   private _excluded;

    uint256 public totalBurned;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event WalletUpdated(string indexed walletType, address indexed newWallet);
    event UniswapPairUpdated(address indexed newPair);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromRewards(address indexed account);
    event IncludeInRewards(address indexed account);
    event TaxesDistributed(
        uint256 tithingAmount,
        uint256 burnAmount,
        uint256 reflectionAmount,
        uint256 lpAmount,
        uint256 treasuryAmount
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _treasuryWallet,
        address _lpWallet,
        address _tithingWallet
    ) ERC20("VictorVoltage", "V V") Ownable(msg.sender) {
        require(_treasuryWallet  != address(0), "Zero treasury");
        require(_lpWallet        != address(0), "Zero LP");
        require(_tithingWallet   != address(0), "Zero tithing");

        treasuryWallet = _treasuryWallet;
        lpWallet       = _lpWallet;
        tithingWallet  = _tithingWallet;

        _tTotal = INITIAL_SUPPLY;
        _rTotal = type(uint256).max - (type(uint256).max % _tTotal);

        // mint and initial reflection balance
        _mint(_msgSender(), _tTotal);
        _rOwned[_msgSender()] = _rTotal;

        // exclude deployer & contract from fees
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;

        // exclude contract and zero address from rewards
        excludeFromReward(address(this));
        excludeFromReward(address(0));

        maxTxAmount = _tTotal / 100; // 1%
    }

    /*//////////////////////////////////////////////////////////////
                           ERC20 PUBLIC OVERRIDES
    //////////////////////////////////////////////////////////////*/
    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        _taxTransfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override whenNotPaused returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _taxTransfer(from, to, amount);
        return true;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromReward[account]) {
            return _tOwned[account];
        }
        return tokenFromReflection(_rOwned[account]);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    function _taxTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(amount > 0, "Zero amount");
        require(amount <= maxTxAmount, "Exceeds maxTx");

        bool takeFee = !_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient];
        uint16 taxBp = takeFee
            ? ((sender == uniswapPair || recipient == uniswapPair)
                ? TRADE_TAX_BPS
                : TRANSFER_TAX_BPS)
            : 0;

        uint256 fee = amount * taxBp / 10_000;
        if (fee > 0) {
            ERC20._transfer(sender, address(this), fee);
            _distributeFee(fee);
        }

        ERC20._transfer(sender, recipient, amount - fee);
    }

    /*//////////////////////////////////////////////////////////////
                            REFLECTION OPERATIONS
    //////////////////////////////////////////////////////////////*/
    function _reflect(uint256 tReflect) private {
        uint256 currentRate = _getRate();
        uint256 rReflect     = tReflect * currentRate;
        _rTotal -= rReflect;
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(rAmount <= _rTotal, "Exceeds rTotal");
        return rAmount / _getRate();
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply()
        private
        view
        returns (uint256, uint256)
    {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        for (uint256 i = 0; i < _excluded.length; i++) {
            address excl = _excluded[i];
            if (_rOwned[excl] > rSupply || _tOwned[excl] > tSupply) {
                return (_rTotal, _tTotal);
            }
            rSupply -= _rOwned[excl];
            tSupply -= _tOwned[excl];
        }
        if (rSupply < (_rTotal / _tTotal)) {
            return (_rTotal, _tTotal);
        }
        return (rSupply, tSupply);
    }

    /*//////////////////////////////////////////////////////////////
                            TAX DISTRIBUTION
    //////////////////////////////////////////////////////////////*/
    function _distributeFee(uint256 fee) private nonReentrant {
        uint256 tithingAmt  = fee * TITHING_BPS    / TRADE_TAX_BPS;
        uint256 burnAmt     = fee * BURN_BPS       / TRADE_TAX_BPS;
        uint256 reflectAmt  = fee * REFLECTION_BPS / TRADE_TAX_BPS;
        uint256 lpAmt       = fee * LP_BPS         / TRADE_TAX_BPS;
        uint256 treasuryAmt = fee - tithingAmt - burnAmt - reflectAmt - lpAmt;

        ERC20._transfer(address(this), tithingWallet, tithingAmt);
        ERC20._transfer(address(this), lpWallet,       lpAmt);
        ERC20._transfer(address(this), treasuryWallet, treasuryAmt);

        _burn(address(this), burnAmt);
        totalBurned += burnAmt;
        _tTotal    -= burnAmt;

        _reflect(reflectAmt);

        emit TaxesDistributed(
            tithingAmt,
            burnAmt,
            reflectAmt,
            lpAmt,
            treasuryAmt
        );
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setUniswapPair(address pair) external onlyOwner {
        require(pair != address(0), "Zero pair");
        uniswapPair = pair;
        emit UniswapPairUpdated(pair);
    }

    function updateTreasuryWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero addr");
        treasuryWallet = newWallet;
        emit WalletUpdated("Treasury", newWallet);
    }

    function updateLpWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero addr");
        lpWallet = newWallet;
        emit WalletUpdated("LP", newWallet);
    }

    function updateTithingWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero addr");
        tithingWallet = newWallet;
        emit WalletUpdated("Tithing", newWallet);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        _isExcludedFromFee[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcludedFromReward[account], "Already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excluded.push(account);
        emit ExcludeFromRewards(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcludedFromReward[account], "Not excluded");
        for (uint256 i; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromReward[account] = false;
                _excluded.pop();
                break;
            }
        }
        emit IncludeInRewards(account);
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        require(amount > 0 && amount <= _tTotal / 10, "Invalid maxTx");
        maxTxAmount = amount;
        emit WalletUpdated("MaxTx", address(uint160(amount)));
    }
}

 

     

   
       
      
      
   
     
       
        
        

    

  
     
    
   
 
