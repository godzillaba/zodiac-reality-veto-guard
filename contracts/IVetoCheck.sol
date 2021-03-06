// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

interface IVetoCheck {
    function canVeto(address account) external view returns (bool);
}