/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.4.24;

import "../../utils/SafeMath/SafeMath.sol";
import "../Exchange/MixinAssetProxyDispatcher.sol";
import "./MixinAuthorizable.sol";


contract MultiAssetProxy is
    SafeMath,
    MixinAssetProxyDispatcher,
    MixinAuthorizable
{
    // Id of this proxy.
    bytes4 constant internal PROXY_ID = bytes4(keccak256("MultiAsset(uint256[],bytes[])"));

    // solhint-disable-next-line payable-fallback
    function ()
        external
    {
        assembly {
            // The first 4 bytes of calldata holds the function selector
            let selector := and(calldataload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)

            // `transferFrom` will be called with the following parameters:
            // assetData Encoded byte array.
            // from Address to transfer asset from.
            // to Address to transfer asset to.
            // amount Amount of asset to transfer.
            // bytes4(keccak256("transferFrom(bytes,address,address,uint256)")) = 0xa85e59e4
            if eq(selector, 0xa85e59e400000000000000000000000000000000000000000000000000000000) {

                // To lookup a value in a mapping, we load from the storage location keccak256(k, p),
                // where k is the key left padded to 32 bytes and p is the storage slot
                mstore(0, and(caller, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(32, authorized_slot)

                // Revert if authorized[msg.sender] == false
                if iszero(sload(keccak256(0, 64))) {
                    // Revert with `Error("SENDER_NOT_AUTHORIZED")`
                    mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(32, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(64, 0x0000001553454e4445525f4e4f545f415554484f52495a454400000000000000)
                    mstore(96, 0)
                    revert(0, 100)
                }

                // `transferFrom`.
                // The function is marked `external`, so no abi decodeding is done for
                // us. Instead, we expect the `calldata` memory to contain the
                // following:
                //
                // | Area     | Offset | Length  | Contents                            |
                // |----------|--------|---------|-------------------------------------|
                // | Header   | 0      | 4       | function selector                   |
                // | Params   |        | 4 * 32  | function parameters:                |
                // |          | 4      |         |   1. offset to assetData (*)        |
                // |          | 36     |         |   2. from                           |
                // |          | 68     |         |   3. to                             |
                // |          | 100    |         |   4. amount                         |
                // | Data     |        |         | assetData:                          |
                // |          | 132    | 32      | assetData Length                    |
                // |          | 164    | **      | assetData Contents                  |
                //
                // (*): offset is computed from start of function parameters, so offset
                //      by an additional 4 bytes in the calldata.
                //
                // (**): see table below to compute length of assetData Contents
                //
                // WARNING: The ABIv2 specification allows additional padding between
                //          the Params and Data section. This will result in a larger
                //          offset to assetData.

                // Load offset to `assetData`
                let assetDataOffset := calldataload(4)

                // Asset data itself is encoded as follows:
                //
                // | Area     | Offset      | Length  | Contents                            |
                // |----------|-------------|---------|-------------------------------------|
                // | Header   | 0           | 4       | assetProxyId                        |
                // | Params   |             | 2 * 32  | function parameters:                |
                // |          | 4           |         |   1. offset to amounts (*)          |
                // |          | 36          |         |   2. offset to nestedAssetData (*)  |
                // | Data     |             |         | amounts:                            |
                // |          | 68          | 32      | amounts Length                      |
                // |          | 100         | a       | amounts Contents                    | 
                // |          |             |         | nestedAssetData:                    |
                // |          | 100 + a     | 32      | nestedAssetData Length              |
                // |          | 132 + a     | b       | nestedAssetData Contents (offsets)  |
                // |          | 132 + a + b |         | nestedAssetData[0, ..., len]        |

                // Load offset to `amounts`
                // We must add 4 (function selector) + 32 (assetData len) + 4 (assetProxyId) to the assetData offset
                let amountsOffset := calldataload(add(assetDataOffset, 40))

                // Load offsets to `nestedAssetData`
                let nestedAssetDataOffset := calldataload(add(assetDataOffset, 72))

                // Load number of elements in `amounts`
                // We must add 4 (function selector) + 128 (4 params * 32) + 32 (assetData len) + 4 (assetProxyId) + 32 (amounts len) to the amounts offset
                let amountsContentsStart := add(amountsOffset, 200)
                let amountsLen := calldataload(sub(amountsContentsStart, 32))

                // Load number of elements in `nestedAssetData`
                let nestedAssetDataContentsStart := add(nestedAssetDataOffset, 200)
                let nestedAssetDataLen := calldataload(sub(nestedAssetDataContentsStart, 32))

                // Revert if number of elements in `amounts` differs from number of elements in `nestedAssetData`
                if iszero(eq(amountsLen, nestedAssetDataLen)) {
                    // Revert with `Error("LENGTH_MISMATCH")`
                    mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(32, 0x0000002000000000000000000000000000000000000000000000000000000000)
                    mstore(64, 0x0000000f4c454e4754485f4d49534d4154434800000000000000000000000000)
                    mstore(96, 0)
                    revert(0, 100)
                }

                // Copy `transferFrom` selector, offset to `assetData`, `from`, and `to` from calldata to memory
                calldatacopy(
                    0,   // memory can safely be overwritten from beginning
                    0,   // start of calldata
                    100  // length of selector (4) and 3 params (32 * 3)
                )

                // Overwrite existing offset to `assetData` with our own
                mstore(4, 128)
                
                // Load `amount`
                let amount := calldataload(100)
        
                // Calculate number of bytes in `amounts` contents
                let amountsByteLen := mul(amountsLen, 32)

                // Loop through `amounts` and `nestedAssetData`, calling `transferFrom` for each respective element
                for {let i := 0} lt(i, amountsByteLen) {i := add(i, 32)} {

                    // Calculate the total amount
                    let amountsElement := calldataload(add(amountsContentsStart, i))
                    let totalAmount := mul(amountsElement, amount)

                    // Revert if multiplication resulted in an overflow
                    if iszero(eq(div(totalAmount, amount), amountsElement)) {
                        // Revert with `Error("UINT256_OVERFLOW")`
                        mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                        mstore(32, 0x0000002000000000000000000000000000000000000000000000000000000000)
                        mstore(64, 0x0000001055494e543235365f4f564552464c4f57000000000000000000000000)
                        mstore(96, 0)
                        revert(0, 100)
                    }

                    // Write `totalAmount` to memory
                    mstore(100, totalAmount)

                    // Load offset to `nestedAssetData[i]`
                    let nestedAssetDataElementOffset := calldataload(add(nestedAssetDataContentsStart, i))

                    // Load length of `nestedAssetData[i]`
                    let nestedAssetDataElementContentsStart := add(nestedAssetDataElementOffset, 264)
                    let nestedAssetDataElementLen := calldataload(sub(nestedAssetDataElementContentsStart, 32))

                    // Revert if the `nestedAssetData` does not contain a 4 byte `assetProxyId`
                    if lt(nestedAssetDataElementLen, 4) {
                        // Revert with `Error("LENGTH_GREATER_THAN_3_REQUIRED")`
                        mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                        mstore(32, 0x0000002000000000000000000000000000000000000000000000000000000000)
                        mstore(64, 0x0000001e4c454e4754485f475245415445525f5448414e5f335f524551554952)
                        mstore(96, 0x4544000000000000000000000000000000000000000000000000000000000000)
                        revert(0, 100)
                    }

                    // Load AssetProxy id
                    let assetProxyId := and(calldataload(nestedAssetDataElementContentsStart), 0xffffffff00000000000000000000000000000000000000000000000000000000)

                    // To lookup a value in a mapping, we load from the storage location keccak256(k, p),
                    // where k is the key left padded to 32 bytes and p is the storage slot
                    mstore(132, assetProxyId)
                    mstore(164, assetProxies_slot)
                    let assetProxy := sload(keccak256(132, 64))
                    
                    // Revert if AssetProxy with given id does not exist
                    if iszero(assetProxy) {
                        // Revert with `Error("ASSET_PROXY_DOES_NOT_EXIST")`
                        mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                        mstore(32, 0x0000002000000000000000000000000000000000000000000000000000000000)
                        mstore(64, 0x0000001a41535345545f50524f58595f444f45535f4e4f545f45584953540000)
                        mstore(96, 0)
                        revert(0, 100)
                    }
    
                    // Copy `nestedAssetData[i]` from calldata to memory
                    calldatacopy(
                        132,                                // memory slot after `amounts[i]`
                        nestedAssetDataElementOffset,       // location of `nestedAssetData[i]` in calldata
                        add(nestedAssetDataElementLen, 32)  // `nestedAssetData[i].length` plus 32 byte length
                    )

                    // call `assetProxy.transferFrom`
                    let success := call(
                        gas,                                    // forward all gas
                        assetProxy,                             // call address of asset proxy
                        0,                                      // don't send any ETH
                        0,                                      // pointer to start of input
                        add(164, nestedAssetDataElementLen),    // length of input  
                        100,                                    // write output over memory that won't be reused
                        512                                     // reserve 512 bytes for output
                    )

                    if iszero(success) {
                        revert(100, returndatasize())
                    }
                }

                // Return if no `transferFrom` calls reverted
                return(0, 0)
            }

            // Revert if undefined function is called
            revert(0, 0)
        }
    }

    /// @dev Gets the proxy id associated with the proxy address.
    /// @return Proxy id.
    function getProxyId()
        external
        pure
        returns (bytes4)
    {
        return PROXY_ID;
    }
}