// Contract where users can buy and sell tokens
module we_hate_the_ui_contracts::manager{
   use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object_table::{Self, ObjectTable};

    public struct ManagerAdminCap has key {
        id: UID
    }

    public struct ManagedTokenData<T> has key {
        id: UID,
        token: TreasuryCap<T>,
        
    } 



   /// Module initializer is called only once on module publish.
     fun init(ctx: &mut TxContext) {
        // On init, create an instance of TeacherCap and assign to the publisher
        transfer::transfer(ManagerAdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx))
    }


    // Someone with the ManagerAdminCap can create and transfer a new ManagerAdminCap instance to another address
    // Lets us avoid sharing private keys
    public fun add_additional_admin(_: &ManagerAdminCap, new_admin_address: address, ctx: &mut TxContext){
        transfer::transfer(
            ManagerAdminCap {
                id: object::new(ctx)
            }, new_admin_address)
    }

   /// Manager can mint new coins
    public fun buy_tokens<T>(
         treasury_cap: &mut TreasuryCap<T>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        // If this is called from the backend ONLY the manager should be able to call it.
        
        // This function can be used to mint ANY token, we want to check the owner of the TreasuryCap to make sure its the manager contract, other users shouldn't be able to call this
        // We can block users from calling this function by taking the ManagerAdminCap
        // Initial version: Check if user has deposited AMOUNT Sui to purchase the tokens
        // Note: We know what the coin is because it's in the TreasuryCap
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
    }


}

// Manager + Token package id:  0xdf0ef32707de5ab9d1a369e4fc44ce8c71d66d1630dac527b0b73c759d99243e
// TreasuryCap: 0xd0232346daffdfb68de82c6a252bc5133bdb456eb26f5ed45a013e6d572cf0c2
// 