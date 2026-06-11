// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MultisigLite {
    IERC20 public immutable usdc;
    address[] public signers;
    uint256 public required;

    struct Tx {
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
    }
    Tx[] public txs;
    mapping(uint256 => mapping(address => bool)) public approved;
    mapping(address => bool) public isSigner;

    event TxProposed(uint256 indexed id, address to, uint256 amount);
    event TxApproved(uint256 indexed id, address signer);
    event TxExecuted(uint256 indexed id);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
        signers.push(msg.sender);
        isSigner[msg.sender] = true;
        required = 1;
    }

    modifier onlySigner() { require(isSigner[msg.sender], "NOT_SIGNER"); _; }

    function addSigner(address s) external onlySigner {
        require(!isSigner[s], "ALREADY");
        signers.push(s); isSigner[s] = true;
    }

    function setRequired(uint256 r) external onlySigner {
        require(r > 0 && r <= signers.length, "BAD_REQ");
        required = r;
    }

    function propose(address to, uint256 amount) external onlySigner returns (uint256) {
        txs.push(Tx(to, amount, 0, false));
        emit TxProposed(txs.length - 1, to, amount);
        return txs.length - 1;
    }

    function approve(uint256 id) external onlySigner {
        require(!approved[id][msg.sender], "ALREADY_APPROVED");
        approved[id][msg.sender] = true;
        txs[id].approvals++;
        emit TxApproved(id, msg.sender);
        if (txs[id].approvals >= required && !txs[id].executed) _execute(id);
    }

    function _execute(uint256 id) internal {
        Tx storage t = txs[id];
        t.executed = true;
        require(usdc.transfer(t.to, t.amount), "TRANSFER_FAILED");
        emit TxExecuted(id);
    }
}
