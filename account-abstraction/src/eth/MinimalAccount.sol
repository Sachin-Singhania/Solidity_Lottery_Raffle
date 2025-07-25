// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {SIG_VALIDATION_FAILED,SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
contract MinimalAccount is IAccount, Ownable   {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    IEntryPoint private immutable i_entryPoint;
    constructor(address _entryPoint) Ownable(msg.sender){
        i_entryPoint = IEntryPoint(_entryPoint);
    }
    modifier onlyEntryPoint() {
         if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }
    modifier onlyEntryPointorOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }
        function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256){

        uint256 validationData=  _validateSignature(userOp,userOpHash);
        _payPrefund(missingAccountFunds);
        return validationData;
    }
    function execute( address dest,uint256 value,bytes calldata data) external onlyEntryPointorOwner{
         (bool sucess,)=dest.call{  
            value:value
          }       (
            data
            );
            if(!sucess) revert("Execution failed");
    }
    function _validateSignature ( PackedUserOperation calldata userOp,bytes32 userOpHash) public returns (uint256) {
        bytes32 ethSignedMessageHash= MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer= ECDSA.recover(ethSignedMessageHash,userOp.signature);
         if(signer!= owner()) return SIG_VALIDATION_FAILED;
         return SIG_VALIDATION_SUCCESS;

    }
    function _payPrefund(uint256 missingAccountFunds) internal {
        if(missingAccountFunds!=0){
        (bool success,) = payable(msg.sender).call{value: missingAccountFunds,gas: type(uint256).max}("");
        (success);
        }
    }
    function getEntryPoint () external view returns (address) {
        return address(i_entryPoint);
        }

}
