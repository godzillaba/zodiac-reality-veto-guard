//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@gnosis.pm/zodiac/contracts/guard/BaseGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IVetoCheck.sol";
// import "@gnosis.pm/zodiac/contracts/factory/FactoryFriendly.sol";


interface IZodiacReality {
    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 nonce
    ) external view returns (bytes32);
}

contract ZodiacRealityVetoGuard is BaseGuard, Ownable {
    address public vetoCheck;
    mapping(uint256 => bytes32[]) public hashesByNonce;
    uint256 public maxNonce;

    event Check(address to, uint256 value, bytes data, Enum.Operation operation);
    event Foo(bytes32 x);

    constructor(address _vetoCheck) {
        vetoCheck = _vetoCheck;
    }

    modifier onlyVetoer() {
        require(vetoCheck != address(0), "Veto is disabled");
        require(IVetoCheck(vetoCheck).canVeto(msg.sender), "This account is not a vetoer");
        _;
    }

    function changeVetoCheck(address _vetoCheck) public onlyOwner {
        vetoCheck = _vetoCheck;
    }

    function vetoTransaction(bytes32 txHash, uint256 txNonce) public onlyVetoer {
        hashesByNonce[txNonce].push(txHash);
        maxNonce = txNonce > maxNonce ? txNonce : maxNonce;
    }

    function cancelVetoTransaction(bytes32 txHash, uint256 txNonce) public onlyVetoer {
        uint256 length = hashesByNonce[txNonce].length;
        for (uint256 i = 0; i < length; i++) {
            if (hashesByNonce[txNonce][i] == txHash) {
                hashesByNonce[txNonce][i] = hashesByNonce[txNonce][length-1];
                hashesByNonce[txNonce].pop();
                return;
            }
        }
    }
    
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external  override {
        emit Check(to, value, data, operation);
        for (uint256 nonce = 0; nonce <= maxNonce; nonce++) {
            bytes32 hashForThisNonce = IZodiacReality(msg.sender).getTransactionHash(to, value, data, operation, nonce);
            for (uint256 i = 0; i < hashesByNonce[nonce].length; i++) {
                emit Foo(hashesByNonce[nonce][i]);
                require(hashesByNonce[nonce][i] != hashForThisNonce, "This transaction has been vetoed");
            }
        }
    }

    function checkAfterExecution(bytes32, bool) external view override {}
}
