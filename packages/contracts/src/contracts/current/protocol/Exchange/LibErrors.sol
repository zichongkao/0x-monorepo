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

pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

contract LibErrors {

    // Error Codes
    enum Errors {
        INVALID,                           // The first (default) value is invalid
        SUCCESS,                           // Operation executed normaly
        ORDER_INVALID,                     // Order is invalid
        ORDER_SIGNATURE_INVALID,           // Signature invalid
        ORDER_SENDER_INVALID,              // Sender invalid
        ORDER_EXPIRED,                     // Order has already expired
        ORDER_FULLY_FILLED,                // Order has already been fully filled
        ORDER_CANCELLED,                   // Order has already been cancelled
        INVALID_TAKER,                     // Order can not be filled by taker
        ROUNDING_ERROR_TOO_LARGE,          // Rounding error too large
        INSUFFICIENT_BALANCE_OR_ALLOWANCE  // Insufficient balance or allowance for token transfer
    }

    event ExchangeError(uint8 indexed errorId, bytes32 indexed orderHash);

    function isOrderValid(Errors status) internal pure returns (bool) {
        if (status == Errors.ORDER_INVALID) return false;
        if (status == Errors.ORDER_SENDER_INVALID) return false;
        if (status == Errors.ORDER_SIGNATURE_INVALID) return false;
        return true;
    }

    function isOrderFillable(Errors status) internal pure returns (bool) {
        return (status == Errors.SUCCESS);
    }
}
