from step08.code import Account, bank

a, b = bank.transfer(Account(owner="ann", balance=100), Account(owner="bob", balance=5), 30)
print(type(a).__name__, a, b)
print(bank.transfer(a, b, 1000))
