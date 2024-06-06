// module kriya::spot_dex {
//     use sui::object::{Self, UID, ID};
//     use sui::coin::{Self, Coin, CoinMetadata};
//     use sui::balance::{Self, Supply, Balance};
//     use sui::transfer;
//     use sui::math;
//     use sui::table::{Self, Table};
//     use sui::tx_context::{Self, TxContext};
//     use sui::event;
//     use kriya::safe_math;
//     use kriya::utils;

//     /// For when supplied Coin is zero.
//     const EZeroAmount: u64 = 0;
//     /// Allowed values are: [0-10000).
//     const EWrongFee: u64 = 1;
//     const EReservesEmpty: u64 = 2;
//     const EInsufficientBalance: u64 = 3;
//     const ELiquidityInsufficientBAmount: u64 = 4;
//     const ELiquidityInsufficientAAmount: u64 = 5;
//     const ELiquidityOverLimitADesired: u64 = 6;
//     const ELiquidityInsufficientMinted: u64 = 7;
//     const ESwapOutLessthanExpected: u64 = 8;
//     const EUnauthorized: u64 = 9;
//     const ECallerNotAdmin: u64 = 10;
//     const ESwapDisabled: u64 = 11;
//     const EAddLiquidityDisabled: u64 = 12;
//     const EAlreadyWhitelisted: u64 = 13;
//     /// When not enough liquidity minted.
//     const ENotEnoughInitialLiquidity: u64 = 14;
//     const ERemoveAdminNotAllowed: u64 = 15;
//     const EIncorrectPoolConstantPostSwap: u64 = 16;
//     const EFeeInvalid: u64 = 17;
//     const EAmountZero: u64 = 18;
//     const EReserveZero: u64 = 19;
//     const EInvalidLPToken: u64 = 20;

//     /// The integer scaling setting for fees calculation.
//     const FEE_SCALING: u128 = 1000000;
    
//     /// Minimal liquidity.
//     const MINIMAL_LIQUIDITY: u64 = 1000;

//     /// The Pool token_x that will be used to mark the pool share
//     /// of a liquidity provider. The first type parameter stands
//     /// for the witness type of a pool. The seconds is for the
//     /// coin held in the pool.
//     struct LSP<phantom X, phantom Y> has drop {}
//     struct KriyaLPToken<phantom X, phantom Y> has key, store {
//         id: UID,
//         pool_id: ID,
//         lsp: Coin<LSP<X, Y>>
//     }

//     struct ProtocolConfigs has key {
//         id: UID,
//         protocol_fee_percent_uc: u64,
//         lp_fee_percent_uc: u64,
//         protocol_fee_percent_stable: u64,
//         lp_fee_percent_stable: u64,
//         is_swap_enabled: bool,
//         is_deposit_enabled: bool,
//         is_withdraw_enabled: bool,
//         admin: address,
//         whitelisted_addresses: Table<address, bool>
//     }

//     /// Kriya AMM Pool object.
//     struct Pool<phantom X, phantom Y> has key {
//         id: UID,
//         /// Balance of Coin<Y> in the pool.
//         token_y: Balance<Y>,
//         /// Balance of Coin<X> in the pool.
//         token_x: Balance<X>,
//         /// LP total supply share.
//         lsp_supply: Supply<LSP<X, Y>>,
//         /// Minimum required liquidity, non-withdrawable
//         lsp_locked: Balance<LSP<X, Y>>,
//         /// LP fee percent. Range[1-10000] (30 -> 0.3% fee)
//         lp_fee_percent: u64,
//         /// Protocol fee percent. Range[1-10000] (30 -> 0.3% fee)
//         protocol_fee_percent: u64,
//         /// Protocol fee pool to hold collected Coin<X> as fee.
//         protocol_fee_x: Balance<X>,
//         /// Protocol fee pool to hold collected Coin<Y> as fee.
//         protocol_fee_y: Balance<Y>,
//         /// If the pool uses the table_curve_formula
//         is_stable: bool,
//         /// 10^ Decimals of Coin<X>
//         scaleX: u64,
//         /// 10^ Decimals of Coin<Y>
//         scaleY: u64,
//         /// if trading is active for this pool
//         is_swap_enabled: bool,
//         /// if adding liquidity is enabled
//         is_deposit_enabled: bool,
//         /// if removing liquidity is enabled
//         is_withdraw_enabled: bool
//     }

//     /* Events */

//     struct PoolCreatedEvent has drop, copy {
//         pool_id: ID,
//         creator: address,
//         lp_fee_percent: u64,
//         protocol_fee_percent: u64,
//         is_stable: bool,
//         scaleX: u64,
//         scaleY: u64
//     }

//     struct PoolUpdatedEvent has drop, copy {
//         pool_id: ID,
//         lp_fee_percent: u64,
//         protocol_fee_percent: u64,
//         is_stable: bool,
//         scaleX: u64,
//         scaleY: u64
//     }

//     struct LiquidityAddedEvent has drop, copy {
//         pool_id: ID,
//         liquidity_provider: address,
//         amount_x: u64,
//         amount_y: u64,
//         lsp_minted: u64
//     }

//     struct LiquidityRemovedEvent has drop, copy {
//         pool_id: ID,
//         liquidity_provider: address,
//         amount_x: u64,
//         amount_y: u64,
//         lsp_burned: u64
//     }

//     struct SwapEvent<phantom T> has drop, copy {
//         pool_id: ID,
//         user: address,
//         reserve_x: u64,
//         reserve_y: u64,
//         amount_in: u64,
//         amount_out: u64
//     }

//     struct ConfigUpdatedEvent has drop, copy {
//         protocol_fee_percent_uc: u64,
//         lp_fee_percent_uc: u64,
//         protocol_fee_percent_stable: u64,
//         lp_fee_percent_stable: u64,
//         is_swap_enabled: bool,
//         is_deposit_enabled: bool,
//         is_withdraw_enabled: bool,
//         admin: address
//     }

//     struct WhitelistUpdatedEvent has drop, copy {
//         addr: address,
//         is_whitelisted: bool
//     }


//     fun emit_pool_created_event<X, Y>(pool: &Pool<X, Y>, ctx: &mut TxContext) {
//         let v0 = PoolCreatedEvent{
//             pool_id              : *object::uid_as_inner(&pool.id), 
//             creator              : tx_context::sender(ctx), 
//             lp_fee_percent       : pool.lp_fee_percent, 
//             protocol_fee_percent : pool.protocol_fee_percent, 
//             is_stable            : pool.is_stable, 
//             scaleX               : pool.scaleX, 
//             scaleY               : pool.scaleY,
//         };
//         0x2::event::emit<PoolCreatedEvent>(v0);
//     }

//       fun emit_liquidity_added_event(pool_id: 0x2::object::ID, liquidity_provider: address, amount_x: u64, amount_y: u64, lsp_minted: u64) {
//         let v0 = LiquidityAddedEvent{
//             pool_id            : pool_id, 
//             liquidity_provider : liquidity_provider, 
//             amount_x           : amount_x, 
//             amount_y           : amount_y, 
//             lsp_minted         : lsp_minted,
//         };
//         0x2::event::emit<LiquidityAddedEvent>(v0);
//     }
//     /* Entry Functions */

//     /// Entry function for create new `Pool` for Coin<X> & Coin<Y>. Each Pool holds a `Coin<X>`
//     /// and a `Coin<Y>`. Swaps are available in both directions.
//     ///
//     /// TODO: this should be create_pool and internal function should have the trailing '_'
//     public entry fun create_pool_<X, Y>(
//         protocol_configs: &ProtocolConfigs,
//         is_stable: bool,
//         coin_metadata_x: &CoinMetadata<X>,
//         coin_metadata_y: &CoinMetadata<Y>,
//         ctx: &mut TxContext
//     ) {
//         transfer::share_object<Pool<X, Y>>(create_pool<X, Y>(protocol_configs, is_stable, coin_metadata_x, coin_metadata_y, ctx));
//     }

//     /// Create new `Pool` for Coin<X> & Coin<Y>. Each Pool holds a `Coin<X>`
//     /// and a `Coin<Y>`. Swaps are available in both directions.
//     /// todo: check if witness object needs to be passed to make it admin only.
//     public fun create_pool<X, Y>(
//         protocol_configs: &ProtocolConfigs,
//         is_stable: bool,
//         coin_metadata_x: &CoinMetadata<X>,
//         coin_metadata_y: &CoinMetadata<Y>,
//         ctx: &mut TxContext
//     ): Pool<X, Y> {
//           let (v0, v1) = get_fee_from_protocol_configs(protocol_configs, is_stable);
//         assert!(((v0 + v1) as u128) < 1000000, 1);
//         let v2 = LSP<X, Y>{dummy_field: false};
//         let v3 = Pool<X, Y>{
//             id                   : object::new(ctx), 
//             token_y              : balance::zero<Y>(), 
//             token_x              : balance::zero<X>(), 
//             lsp_supply           : balance::create_supply<LSP<X, Y>>(v2), 
//             lsp_locked           : balance::zero<LSP<X, Y>>(), 
//             lp_fee_percent       : v0, 
//             protocol_fee_percent : v1, 
//             protocol_fee_x       : balance::zero<X>(), 
//             protocol_fee_y       : balance::zero<Y>(), 
//             is_stable            : is_stable, 
//             scaleX               : get_scale_from_coinmetadata<X>(coin_metadata_x), 
//             scaleY               : get_scale_from_coinmetadata<Y>(coin_metadata_y), 
//             is_swap_enabled      : true, 
//             is_deposit_enabled   : true, 
//             is_withdraw_enabled  : true,
//         };
//         emit_pool_created_event<X, Y>(&v3, ctx);
//         v3
//     }

//     /// Entrypoint for the `swap_token_y` method. Sends swapped token_x
//     /// to sender.
//     public entry fun swap_token_y_<X, Y>(
//         pool: &mut Pool<X, Y>, token_y: Coin<Y>, amount_y: u64, min_recieve_x: u64, ctx: &mut TxContext
//     ) {
//         abort 0
//     }

//     /// Swap `Coin<Y>` for the `Coin<X>`.
//     /// Returns Coin<X>.
//     public fun swap_token_y<X, Y>(
//         pool: &mut Pool<X, Y>, token_y: Coin<Y>, amount: u64, min_recieve_x: u64, ctx: &mut TxContext
//     ): Coin<X> {
//         abort 0
//     }

//     /// Entry point for the `swap_token_x` method. Sends swapped token_y
//     /// to the sender.
//     public entry fun swap_token_x_<X, Y>(
//         pool: &mut Pool<X, Y>, token_x: Coin<X>, amount: u64, min_recieve_y: u64, ctx: &mut TxContext
//     ) {
//         abort 0
//     }

//     /// Swap `Coin<X>` for the `Coin<Y>`.
//     /// Returns the swapped `Coin<Y>`.
//     public fun swap_token_x<X, Y>(
//         pool: &mut Pool<X, Y>, token_x: Coin<X>, amount: u64, min_recieve_y: u64, ctx: &mut TxContext
//     ): Coin<Y> {
//         abort 0
//     }

//     /// Entrypoint for the `add_liquidity` method. Sends `Coin<LSP>` to
//     /// the transaction sender.
//     public entry fun add_liquidity_<X, Y>(
//         pool: &mut Pool<X, Y>, 
//         token_y: Coin<Y>,
//         token_x: Coin<X>, 
//         token_y_amount: u64,
//         token_x_amount: u64,
//         amount_y_min_deposit: u64,
//         amount_x_min_deposit: u64,
//         ctx: &mut TxContext
//     ) {
//        transfer::transfer<KriyaLPToken<X, Y>>(add_liquidity<X, Y>(pool, token_y, token_x, token_y_amount, token_x_amount, amount_y_min_deposit, amount_x_min_deposit, ctx), tx_context::sender(ctx));
//     }

//     /// Add liquidity to the `Pool`. Sender needs to provide both
//     /// `Coin<Y>` and `Coin<X>`, and in exchange he gets `Coin<LSP>` -
//     /// liquidity provider tokens.
//     public fun add_liquidity<X, Y>(
//         pool: &mut Pool<X, Y>, 
//         token_y: Coin<Y>, 
//         token_x: Coin<X>, 
//         token_y_amount: u64,
//         token_x_amount: u64,
//         amount_y_min_deposit: u64,
//         amount_x_min_deposit: u64,
//         ctx: &mut TxContext
//     ): KriyaLPToken<X, Y> {
//         assert!(pool.is_deposit_enabled, 12);
//         let v0 = coin::value<Y>(&token_y);
//         let v1 = coin::value<X>(&token_x);
//         assert!(token_y_amount > 0 && token_x_amount > 0, 0);
//         assert!(v0 >= token_y_amount && v1 >= token_x_amount, 3);
//         let (v2, v3) = get_amount_for_add_liquidity<X, Y>(pool, token_x_amount, token_y_amount, amount_x_min_deposit, amount_y_min_deposit);
//         if (v1 > v2) {
//             transfer::public_transfer<Coin<X>>(coin::split<X>(&mut token_x, v1 - v2, ctx), tx_context::sender(ctx));
//         };
//         if (v0 > v3) {
//             transfer::public_transfer<Coin<Y>>(coin::split<Y>(&mut token_y, v0 - v3, ctx), tx_context::sender(ctx));
//         };
//         let v4 = mint_lsp_token<X, Y>(pool, coin::into_balance<X>(token_x), coin::into_balance<Y>(token_y), ctx);
//         emit_liquidity_added_event(*object::uid_as_inner(&pool.id), tx_context::sender(ctx), v2, v3, coin::value<LSP<X, Y>>(&v4));
//         KriyaLPToken<X, Y>{
//             id      : object::new(ctx), 
//             pool_id : *object::uid_as_inner(&pool.id), 
//             lsp     : v4,
//         }
//     }

//     /// Entrypoint for the `remove_liquidity` method. Transfers
//     /// withdrawn assets to the sender.
//     public entry fun remove_liquidity_<X, Y>(
//         pool: &mut Pool<X, Y>,
//         lp_token: KriyaLPToken<X, Y>,
//         amount: u64,
//         ctx: &mut TxContext
//     ) {
//         abort 0
//     }

//     /// Remove liquidity from the `Pool` by burning `Coin<LSP>`.
//     /// Returns `Coin<X>` and `Coin<Y>`.
//     public fun remove_liquidity<X, Y>(
//         pool: &mut Pool<X, Y>,
//         lp_token: KriyaLPToken<X, Y>,
//         amount: u64,
//         ctx: &mut TxContext
//     ): (Coin<Y>, Coin<X>) {
//         abort 0
//     }

//     /* Public geters */

//     /// Get TokenX/Y balance & treasury cap. A Getter function to get frequently get values:
//     /// - amount of token_y
//     /// - amount of token_x
//     /// - total supply of LSP
//     public fun get_reserves<X, Y>(pool: &Pool<X, Y>): (u64, u64, u64) {
//         (
//             balance::value(&pool.token_y),
//             balance::value(&pool.token_x),
//             balance::supply_value(&pool.lsp_supply)
//         )
//     }

//     public fun lp_token_split<X, Y>(self: &mut KriyaLPToken<X, Y>, split_amount: u64, ctx: &mut TxContext): KriyaLPToken<X, Y> {
//         KriyaLPToken {
//             id: object::new(ctx),
//             pool_id: self.pool_id,
//             lsp: coin::split(&mut self.lsp, split_amount, ctx)
//         }
//     }

//     public fun lp_token_join<X, Y>(self: &mut KriyaLPToken<X, Y>, lp_token: KriyaLPToken<X, Y>) {
//         assert!(self.pool_id == lp_token.pool_id, EInvalidLPToken);
//         let KriyaLPToken {id, pool_id: _, lsp} = lp_token;
//         object::delete(id);
//         coin::join(&mut self.lsp, lsp);
//     }

//     public fun lp_token_value<X, Y>(self: &KriyaLPToken<X, Y>): u64 {
//         coin::value(&self.lsp)
//     }

//     public fun lp_destroy_zero<X, Y>(self: KriyaLPToken<X, Y>) {
//         let KriyaLPToken {id, pool_id: _, lsp} = self;
//         coin::destroy_zero(lsp);
//         object::delete(id);
//     }

//     fun get_scale_from_coinmetadata<X>(coin_metadata: &CoinMetadata<X>) : u64 {
//         math::pow(10, coin::get_decimals<X>(coin_metadata))
//     }


//     fun get_amount_for_add_liquidity<X, Y>(pool: &mut Pool<X, Y>, token_x_amount: u64, token_y_amount: u64, amount_x_min_deposit: u64, amount_y_min_deposit: u64) : (u64, u64) {
//         let (v0, v1, _) = get_reserves<X, Y>(pool);
//         if (v1 == 0 && v0 == 0) {
//             (token_x_amount, token_y_amount)
//         } else {
//             let v5 = get_token_amount_to_maintain_ratio(token_x_amount, v1, v0);
//             let (v6, v7) = if (v5 <= token_y_amount) {
//                 assert!(v5 >= amount_y_min_deposit, 4);
//                 (token_x_amount, v5)
//             } else {
//                 let v8 = get_token_amount_to_maintain_ratio(token_y_amount, v0, v1);
//                 assert!(v8 <= token_x_amount, 6);
//                 assert!(v8 >= amount_x_min_deposit, 5);
//                 (v8, token_y_amount)
//             };
//             (v6, v7)
//         }
//     }

//    fun get_token_amount_to_maintain_ratio(token_amount: u64, arg1: u64, arg2: u64) : u64 {
//         assert!(token_amount > 0, 18);
//         assert!(arg1 > 0 && arg2 > 0, 19);
//         (safe_math::safe_mul_div_u64(token_amount, arg2, arg1) as u64)
//     }

//     #[test_only]
//     public fun init_for_testing(ctx: &mut TxContext) {
//         init(ctx)
//     }

//     #[test_only]
//     public fun mint_lp_token<X, Y>(lsp: Coin<LSP<X, Y>>, pool: &Pool<X, Y>, ctx: &mut TxContext): KriyaLPToken<X, Y> {
//         KriyaLPToken<X, Y> {
//             id: object::new(ctx),
//             pool_id: *object::uid_as_inner(&pool.id),
//             lsp: lsp
//         }
//     }
// }