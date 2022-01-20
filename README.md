#Explanation
1. Users can enter the lottery with ETH based on a USD fee. E.g. if lottery ticket fee is USD50, then users have to pay with ETH based on a conversion rate (most likely taken from Chainlink oracle)
2. An admin will choose when the lottery is over
3. The lottery will select a random winner

#How do we want to test?
1. 'mainnet-fork'
2. 'development' with mocks
3. 'testnet'

Q. If there is an admin, will this app be decentralized?
A. Not truly decentralized

Q. Could this app be decentralized?
A. Possibly in future interations. The admin would have to be changed, by using a DAO be the admin or have the lottery open & close based on some time parameters (e.g. Chainlink Keepers)

