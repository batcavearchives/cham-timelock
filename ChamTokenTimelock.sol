// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.3/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CHAM Token Timelock for Hyper EVM
/// @notice Owner locks CHAM until a timestamp; after expiry, owner can withdraw any (or all) tokens,
/// and then relock the remainder either separately or atomically.
contract ChamTokenTimelock is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice CHAM token contract address
    IERC20 public immutable cham;

    /// @notice UNIX timestamp when tokens unlock
    uint256 public unlockTime;

    /// @notice Amount of CHAM currently locked
    uint256 public lockedAmount;

    /// @dev Emitted when tokens are locked
    event Locked(uint256 amount, uint256 unlockTime);

    /// @dev Emitted when the lock is extended
    event Relocked(uint256 newUnlockTime);

    /// @dev Emitted when tokens are withdrawn
    event Withdrawn(address indexed to, uint256 amount);

    /// @param _chamAddress The CHAM token contract
    constructor(address _chamAddress) {
        require(_chamAddress != address(0), "Zero address");
        cham = IERC20(_chamAddress);
    }

    /// @notice Initial lock of CHAM until `newUnlockTime`
    /// @dev Owner must approve this contract for `amount` before calling
    /// @param amount Number of CHAM tokens to lock
    /// @param newUnlockTime UNIX timestamp when they unlock
    function lock(uint256 amount, uint256 newUnlockTime)
        external
        onlyOwner
        nonReentrant
    {
        require(lockedAmount == 0, "Already locked");
        require(amount > 0, "Amount must be > 0");
        require(newUnlockTime > block.timestamp, "Unlock in future");

        cham.safeTransferFrom(msg.sender, address(this), amount);
        lockedAmount = amount;
        unlockTime   = newUnlockTime;

        emit Locked(amount, newUnlockTime);
    }

    /// @notice After expiry, extend lock on the remaining tokens
    /// @param newUnlockTime New UNIX timestamp > now
    function relock(uint256 newUnlockTime) external onlyOwner {
        require(block.timestamp >= unlockTime, "Still locked");
        require(lockedAmount > 0, "Nothing to relock");
        require(newUnlockTime > block.timestamp, "Unlock in future");

        unlockTime = newUnlockTime;
        emit Relocked(newUnlockTime);
    }

    /// @notice After expiry, withdraw up to `amount`
    /// @param amount Number of CHAM tokens to withdraw
    function withdraw(uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(block.timestamp >= unlockTime, "Still locked");
        require(amount > 0 && amount <= lockedAmount, "Invalid amount");

        lockedAmount -= amount;
        cham.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice After expiry, withdraw *all* remaining locked CHAM
    function withdrawAll()
        external
        onlyOwner
        nonReentrant
    {
        require(block.timestamp >= unlockTime, "Still locked");
        uint256 amount = lockedAmount;
        require(amount > 0, "Nothing to withdraw");

        lockedAmount = 0;
        cham.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Withdraw `amount` and immediately relock the remainder until `newUnlockTime`
    /// @param amount Number of CHAM tokens to withdraw
    /// @param newUnlockTime New UNIX timestamp > now
    function withdrawAndRelock(uint256 amount, uint256 newUnlockTime)
        external
        onlyOwner
        nonReentrant
    {
        require(block.timestamp >= unlockTime, "Still locked");
        require(amount > 0 && amount <= lockedAmount, "Invalid amount");
        require(newUnlockTime > block.timestamp, "New unlock in future");

        lockedAmount -= amount;
        unlockTime    = newUnlockTime;

        cham.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
        emit Relocked(newUnlockTime);
    }

    /// @notice Returns the amount of CHAM still locked
    function getLockedAmount() external view returns (uint256) {
        return lockedAmount;
    }

    /// @notice Returns the UNIX timestamp when the lock expires
    function getUnlockTime() external view returns (uint256) {
        return unlockTime;
    }
}
