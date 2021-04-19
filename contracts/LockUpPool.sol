// SPDX-License-Identifier: MIT
import "./openzeppelin/math/SafeMath.sol";
import "./openzeppelin/token/ERC20/IERC20.sol";
import "./openzeppelin/token/ERC20/SafeERC20.sol";
import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/utils/Address.sol";
import './openzeppelin/presets/ERC20PresetMinterPauser.sol';

pragma solidity ^0.7.1;

contract LockUpPool is Initializable, OwnableUpgradeSafe {
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using SafeERC20 for ERC20PresetMinterPauserUpgradeSafe;

  // NOTE: didn't use actual constant variable just in case we may chage it on upgrades
  uint256 public SECONDS_IN_MONTH;

  bool public emergencyMode;

  struct LockUp {
    address tokenAddress;
    uint256 durationInMonths;
    uint256 unlockedAt; // NOTE: Potential block time manipulation by miners
    uint256 amount;
    uint256 exitedAt;
    uint256 interestRate;
    uint256 enteredAt;
  }

  struct UserLockUp {
    uint256 total;
    uint256 accTotal; // info
    uint256 bonusClaimed; // info
    uint256 bonusDebt;
    uint40 lockedUpCount; // accumulative lock-up count (= length of lockUps)
    LockUp[] lockUps;
  }

  struct TokenStats {
    uint256 interestRate;
    uint256 minimumDeposit;
  }

  // Token => TokenStats
  mapping (address => TokenStats) public tokenStats;

  // Array of all added tokens
  address[] public pools;

  // Account => UserLockUps
  mapping (address => UserLockUp) public userLockUps;

  event LockedUp(address indexed token, address indexed account, uint256 amount, uint256 durationInMonths, uint256 timestamp);
  event Exited(address indexed token, address indexed account, uint256 amount, uint256 refundAmount, uint256 timestamp);
  event MasterTransfer(address indexed token, address indexed account, uint256 timestamp);

  function initialize() public initializer {
    OwnableUpgradeSafe.__Ownable_init();

    SECONDS_IN_MONTH = 2592000;
  }

  modifier _isTokenAvailable(address tokenAddress) {
    require(tokenStats[tokenAddress].interestRate > 0, 'POOL_NOT_FOUND');
    _;
  }

  function addNewToken(address tokenAddress, uint256 interestRate, uint256 minimumDeposit) public onlyOwner {
    require(tokenAddress.isContract(), 'INVALID_TOKEN');
    require(interestRate > 0, 'INTEREST_RATE_INVALID');
    require(tokenStats[tokenAddress].interestRate == 0, 'POOL_ALREADY_EXISTS');
    require(minimumDeposit > 0, 'MINIMUM_DEPOSIT_INVALID');

    pools.push(tokenAddress);
    tokenStats[tokenAddress].interestRate = interestRate;
  }

  function updateInterestRate(address tokenAddress, uint256 interestRate) public onlyOwner {
    require(tokenAddress.isContract(), 'INVALID_TOKEN');
    require(interestRate > 0, 'INTEREST_RATE_INVALID');
    require(tokenStats[tokenAddress].interestRate > 0, 'POOL_NOT_FOUND');

    tokenStats[tokenAddress].interestRate = interestRate;
  }

  function updateMinimumDeposit(address tokenAddress, uint256 minimumDeposit) public onlyOwner {
    require(tokenAddress.isContract(), 'INVALID_TOKEN');
    require(minimumDeposit > 0, 'MINIMUM_DEPOSIT_INVALID');
    require(tokenStats[tokenAddress].minimumDeposit > 0, 'POOL_NOT_FOUND');

    tokenStats[tokenAddress].minimumDeposit = minimumDeposit;
  }

  function setEmergencyMode(bool mode) external onlyOwner {
    emergencyMode = mode;
  }

  function makeNewDeposit(address tokenAddress, uint256 amount, uint256 durationInMonths) public virtual _isTokenAvailable(tokenAddress) {
    require(amount > 0, 'INVALID_AMOUNT');
    require(durationInMonths >= 3 && durationInMonths <= 120, 'INVALID_DURATION');

    IERC20 token = IERC20(tokenAddress);

    UserLockUp storage userLockUp = userLockUps[msg.sender];
    TokenStats storage tokenStat = tokenStats[tokenAddress];

    require(amount > tokenStat.minimumDeposit, 'MINIMUM_DEPOSIT_INVALID');

    token.safeTransferFrom(msg.sender, address(this), amount);

    userLockUp.lockUps.push(
      LockUp(
        tokenAddress,
        durationInMonths,
        block.timestamp.add(durationInMonths * SECONDS_IN_MONTH), // unlockedAt
        amount,
        0, // exitedAt
        tokenStat.interestRate,
        block.timestamp
      )
    );

    // Update user lockUp stats
    userLockUp.total = userLockUp.total.add(amount);
    userLockUp.accTotal = userLockUp.accTotal.add(amount);
    userLockUp.lockedUpCount = userLockUp.lockedUpCount + 1;

    emit LockedUp(tokenAddress, msg.sender, amount, durationInMonths, block.timestamp);
  }

  function withdrawDeposit(address tokenAddress, uint256 lockUpId) public virtual _isTokenAvailable(tokenAddress) {
    UserLockUp storage userLockUp = userLockUps[msg.sender];
    LockUp storage lockUp = userLockUp.lockUps[lockUpId];

    require(lockUp.exitedAt == 0, 'ALREADY_EXITED');

    uint256 initialAmount = lockUp.amount;
    uint256 currentInterestRate = lockUp.interestRate;

    uint256 lockupDurationInMonth = lockUp.durationInMonths;
    uint256 elapsedNumberMonths = block.timestamp.sub(lockUp.enteredAt).div(SECONDS_IN_MONTH);

    uint256 bonus = 0;

    require(elapsedNumberMonths > 0, 'REQUIRE_LONGER_HOLD');
    bonus = (initialAmount * currentInterestRate * elapsedNumberMonths / 10000) + ((initialAmount * (1 + (((elapsedNumberMonths / 12) * 20)/100))) - initialAmount);

    uint256 refundAmount = lockUp.amount + bonus;

    // Update lockUp
    lockUp.exitedAt = block.timestamp;

    // Update user lockUp stats
    userLockUp.total = userLockUp.total.sub(initialAmount);

    IERC20 token = IERC20(tokenAddress);
    token.safeTransfer(msg.sender, refundAmount);

    emit Exited(tokenAddress, msg.sender, initialAmount, refundAmount, block.timestamp);
  }

  // Management functions

  function masterDeposit(address tokenAddress, uint256 amount) public onlyOwner _isTokenAvailable(tokenAddress) {
    require(amount > 0, 'INVALID_AMOUNT');

    IERC20 token = IERC20(tokenAddress);

    token.safeTransferFrom(msg.sender, address(this), amount);

    emit MasterTransfer(tokenAddress, msg.sender, block.timestamp);
  }

  function masterWithdraw(address tokenAddress, address recipientAddress, uint256 amount) public onlyOwner _isTokenAvailable(tokenAddress) {
    require(amount > 0, 'INVALID_AMOUNT');

    IERC20 token = IERC20(tokenAddress);
    token.safeTransfer(recipientAddress, amount);

    emit MasterTransfer(tokenAddress, msg.sender, block.timestamp);
  }

  // Utility view functions

  function getTokenInterestRate(address tokenAddress) external view returns(uint256) {
    require(tokenAddress.isContract(), 'INVALID_TOKEN');
    require(tokenStats[tokenAddress].interestRate > 0, 'POOL_NOT_FOUND');

    return tokenStats[tokenAddress].interestRate;
  }

  function poolCount() external view returns(uint256) {
    return pools.length;
  }

  function getDepositInfo(address account, uint256 lockUpId) external view returns (address, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
    LockUp storage lockUp = userLockUps[account].lockUps[lockUpId];

    return (
      lockUp.tokenAddress,
      lockUp.unlockedAt.sub(lockUp.durationInMonths * SECONDS_IN_MONTH),
      lockUp.durationInMonths,
      lockUp.unlockedAt,
      lockUp.amount,
      lockUp.exitedAt,
      lockUp.interestRate,
      lockUp.enteredAt
    );
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}
