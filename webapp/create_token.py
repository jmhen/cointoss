import json

from flask import Flask, render_template

from web3 import Web3,HTTPProvider
from solc import compile_source


app = Flask(__name__)

# Connect web3 instance to our Ganache
w3 = Web3(HTTPProvider('http://localhost:7545'))

contract_source_code = None
contract_source_code_file = 'mytoken.sol'

with open(contract_source_code_file, 'r') as file:
    contract_source_code = file.read()

contract_compiled = compile_source(contract_source_code)
contract_interface = contract_compiled['<stdin>:TossToken']
TossToken = w3.eth.contract(abi=contract_interface['abi'], 
                          bytecode=contract_interface['bin'])

#w3.personal.unlockAccount(w3.eth.accounts[0], '') #  Not needed with Ganache
tx_hash = TossToken.constructor().transact({'from':w3.eth.accounts[0]})
tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)

# Contract Object
token = w3.eth.contract(address=tx_receipt.contractAddress, abi=contract_interface['abi'])

print("Token Created! Contract Address: ", token.address)
