module kriya::spot_dex {
      use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::tx_context::{sender};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{UID, ID, uid_as_inner };
    use kriya::safe_math;
    use kriya::utils;

    use std::debug;
    use std::ascii;
    // use sui::math;
    use sui::event;

    struct LSP<phantom T0, phantom T1> has drop {
        dummy_field: bool,
    }
    
    struct KriyaLPToken<phantom T0, phantom T1> has store, key {
        id: UID,
        pool_id: ID,
        lsp: sui::coin::Coin<LSP<T0, T1>>,
    }
    
    struct ProtocolConfigs has key {
        id: UID,
        protocol_fee_percent_uc: u64,
        lp_fee_percent_uc: u64,
        protocol_fee_percent_stable: u64,
        lp_fee_percent_stable: u64,
        is_swap_enabled: bool,
        is_deposit_enabled: bool,
        is_withdraw_enabled: bool,
        admin: address,
        whitelisted_addresses: 0x2::table::Table<address, bool>,
    }
    
    struct Pool<phantom T0, phantom T1> has key {
        id: UID,
        token_y: sui::balance::Balance<T1>,
        token_x: sui::balance::Balance<T0>,
        lsp_supply: sui::balance::Supply<LSP<T0, T1>>,
        lsp_locked: sui::balance::Balance<LSP<T0, T1>>,
        lp_fee_percent: u64,
        protocol_fee_percent: u64,
        protocol_fee_x: sui::balance::Balance<T0>,
        protocol_fee_y: sui::balance::Balance<T1>,
        is_stable: bool,
        scaleX: u64,
        scaleY: u64,
        is_swap_enabled: bool,
        is_deposit_enabled: bool,
        is_withdraw_enabled: bool,
    }
    
    struct PoolCreatedEvent has copy, drop {
        pool_id: ID,
        creator: address,
        lp_fee_percent: u64,
        protocol_fee_percent: u64,
        is_stable: bool,
        scaleX: u64,
        scaleY: u64,
    }
    
    struct PoolUpdatedEvent has copy, drop {
        pool_id: ID,
        lp_fee_percent: u64,
        protocol_fee_percent: u64,
        is_stable: bool,
        scaleX: u64,
        scaleY: u64,
    }
    
    struct LiquidityAddedEvent has copy, drop {
        pool_id: ID,
        liquidity_provider: address,
        amount_x: u64,
        amount_y: u64,
        lsp_minted: u64,
    }
    
    struct LiquidityRemovedEvent has copy, drop {
        pool_id: ID,
        liquidity_provider: address,
        amount_x: u64,
        amount_y: u64,
        lsp_burned: u64,
    }
    
    struct SwapEvent<phantom T0> has copy, drop {
        pool_id: ID,
        user: address,
        reserve_x: u64,
        reserve_y: u64,
        amount_in: u64,
        amount_out: u64,
    }
    
    struct ConfigUpdatedEvent has copy, drop {
        protocol_fee_percent_uc: u64,
        lp_fee_percent_uc: u64,
        protocol_fee_percent_stable: u64,
        lp_fee_percent_stable: u64,
        is_swap_enabled: bool,
        is_deposit_enabled: bool,
        is_withdraw_enabled: bool,
        admin: address,
    }
    
    struct WhitelistUpdatedEvent has copy, drop {
        addr: address,
        is_whitelisted: bool,
    }
    
    public fun add_liquidity<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::coin::Coin<T1>, arg2: sui::coin::Coin<T0>, arg3: u64, arg4: u64, arg5: u64, arg6: u64, arg7: &mut sui::tx_context::TxContext) : KriyaLPToken<T0, T1> {
        assert!(arg0.is_deposit_enabled, 12);
        let v0 = sui::coin::value<T1>(&arg1);
        let v1 = sui::coin::value<T0>(&arg2);
        assert!(arg3 > 0 && arg4 > 0, 0);
        assert!(v0 >= arg3 && v1 >= arg4, 3);
        let (v2, v3) = get_amount_for_add_liquidity<T0, T1>(arg0, arg4, arg3, arg6, arg5);
        if (v1 > v2) {
            0x2::transfer::public_transfer<sui::coin::Coin<T0>>(sui::coin::split<T0>(&mut arg2, v1 - v2, arg7), sui::tx_context::sender(arg7));
        };
        if (v0 > v3) {
            0x2::transfer::public_transfer<sui::coin::Coin<T1>>(sui::coin::split<T1>(&mut arg1, v0 - v3, arg7), sui::tx_context::sender(arg7));
        };
        let v4 = mint_lsp_token<T0, T1>(arg0, sui::coin::into_balance<T0>(arg2), sui::coin::into_balance<T1>(arg1), arg7);
        emit_liquidity_added_event(*uid_as_inner(&arg0.id), sui::tx_context::sender(arg7), v2, v3, sui::coin::value<LSP<T0, T1>>(&v4));
        KriyaLPToken<T0, T1>{
            id      : sui::object::new(arg7), 
            pool_id : *uid_as_inner(&arg0.id), 
            lsp     : v4,
        }
    }
    
    public entry fun add_liquidity_<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::coin::Coin<T1>, arg2: sui::coin::Coin<T0>, arg3: u64, arg4: u64, arg5: u64, arg6: u64, arg7: &mut sui::tx_context::TxContext) {
        0x2::transfer::transfer<KriyaLPToken<T0, T1>>(add_liquidity<T0, T1>(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7), sui::tx_context::sender(arg7));
    }
    
    fun assert_lp_value_is_increased(arg0: bool, arg1: u64, arg2: u64, arg3: u128, arg4: u128, arg5: u128, arg6: u128) {
        if (arg0) {
            assert!(kriya::utils::lp_value(arg5, arg1, arg6, arg2) > kriya::utils::lp_value(arg3, arg1, arg4, arg2), 16);
        } else {
            assert!(arg5 * arg6 > arg3 * arg4, 16);
        };
    }
    
    public entry fun claim_fees<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: &ProtocolConfigs, arg2: u64, arg3: u64, arg4: &mut sui::tx_context::TxContext) {
        assert!(0x2::table::contains<address, bool>(&arg1.whitelisted_addresses, sui::tx_context::sender(arg4)), 9);
        0x2::transfer::public_transfer<sui::coin::Coin<T0>>(sui::coin::from_balance<T0>(sui::balance::split<T0>(&mut arg0.protocol_fee_x, arg2), arg4), sui::tx_context::sender(arg4));
        0x2::transfer::public_transfer<sui::coin::Coin<T1>>(sui::coin::from_balance<T1>(sui::balance::split<T1>(&mut arg0.protocol_fee_y, arg3), arg4), sui::tx_context::sender(arg4));
    }
    
    public fun create_pool<T0, T1>(arg0: &ProtocolConfigs, arg1: bool, arg2: &sui::coin::CoinMetadata<T0>, arg3: &sui::coin::CoinMetadata<T1>, arg4: &mut sui::tx_context::TxContext) : Pool<T0, T1> {
        let (v0, v1) = get_fee_from_protocol_configs(arg0, arg1);
        assert!(((v0 + v1) as u128) < 1000000, 1);
        let v2 = LSP<T0, T1>{dummy_field: false};
        let v3 = Pool<T0, T1>{
            id                   : sui::object::new(arg4), 
            token_y              : sui::balance::zero<T1>(), 
            token_x              : sui::balance::zero<T0>(), 
            lsp_supply           : sui::balance::create_supply<LSP<T0, T1>>(v2), 
            lsp_locked           : sui::balance::zero<LSP<T0, T1>>(), 
            lp_fee_percent       : v0, 
            protocol_fee_percent : v1, 
            protocol_fee_x       : sui::balance::zero<T0>(), 
            protocol_fee_y       : sui::balance::zero<T1>(), 
            is_stable            : arg1, 
            scaleX               : get_scale_from_coinmetadata<T0>(arg2), 
            scaleY               : get_scale_from_coinmetadata<T1>(arg3), 
            is_swap_enabled      : true, 
            is_deposit_enabled   : true, 
            is_withdraw_enabled  : true,
        };
        emit_pool_created_event<T0, T1>(&v3, arg4);
        v3
    }
    
    public entry fun create_pool_<T0, T1>(arg0: &ProtocolConfigs, arg1: bool, arg2: &sui::coin::CoinMetadata<T0>, arg3: &sui::coin::CoinMetadata<T1>, arg4: &mut sui::tx_context::TxContext) {
        0x2::transfer::share_object<Pool<T0, T1>>(create_pool<T0, T1>(arg0, arg1, arg2, arg3, arg4));
    }
    
    fun emit_config_updated_event(arg0: &ProtocolConfigs) {
        let v0 = ConfigUpdatedEvent{
            protocol_fee_percent_uc     : arg0.protocol_fee_percent_uc, 
            lp_fee_percent_uc           : arg0.lp_fee_percent_uc, 
            protocol_fee_percent_stable : arg0.protocol_fee_percent_stable, 
            lp_fee_percent_stable       : arg0.lp_fee_percent_stable, 
            is_swap_enabled             : arg0.is_swap_enabled, 
            is_deposit_enabled          : arg0.is_deposit_enabled, 
            is_withdraw_enabled         : arg0.is_withdraw_enabled, 
            admin                       : arg0.admin,
        };
        0x2::event::emit<ConfigUpdatedEvent>(v0);
    }
    
    fun emit_liquidity_added_event(arg0: ID, arg1: address, arg2: u64, arg3: u64, arg4: u64) {
        let v0 = LiquidityAddedEvent{
            pool_id            : arg0, 
            liquidity_provider : arg1, 
            amount_x           : arg2, 
            amount_y           : arg3, 
            lsp_minted         : arg4,
        };
        0x2::event::emit<LiquidityAddedEvent>(v0);
    }
    
    fun emit_liquidity_removed_event(arg0: ID, arg1: address, arg2: u64, arg3: u64, arg4: u64) {
        let v0 = LiquidityRemovedEvent{
            pool_id            : arg0, 
            liquidity_provider : arg1, 
            amount_x           : arg2, 
            amount_y           : arg3, 
            lsp_burned         : arg4,
        };
        0x2::event::emit<LiquidityRemovedEvent>(v0);
    }
    
    fun emit_pool_created_event<T0, T1>(arg0: &Pool<T0, T1>, arg1: &mut sui::tx_context::TxContext) {
        let v0 = PoolCreatedEvent{
            pool_id              : *uid_as_inner(&arg0.id), 
            creator              : sui::tx_context::sender(arg1), 
            lp_fee_percent       : arg0.lp_fee_percent, 
            protocol_fee_percent : arg0.protocol_fee_percent, 
            is_stable            : arg0.is_stable, 
            scaleX               : arg0.scaleX, 
            scaleY               : arg0.scaleY,
        };
        0x2::event::emit<PoolCreatedEvent>(v0);
    }
    
    fun emit_pool_updated_event<T0, T1>(arg0: &Pool<T0, T1>) {
        let v0 = PoolUpdatedEvent{
            pool_id              : *uid_as_inner(&arg0.id), 
            lp_fee_percent       : arg0.lp_fee_percent, 
            protocol_fee_percent : arg0.protocol_fee_percent, 
            is_stable            : arg0.is_stable, 
            scaleX               : arg0.scaleX, 
            scaleY               : arg0.scaleY,
        };
        0x2::event::emit<PoolUpdatedEvent>(v0);
    }
    
    fun emit_swap_event<T0>(arg0: ID, arg1: address, arg2: u64, arg3: u64, arg4: u64, arg5: u64) {
        let v0 = SwapEvent<T0>{
            pool_id    : arg0, 
            user       : arg1, 
            reserve_x  : arg2, 
            reserve_y  : arg3, 
            amount_in  : arg4, 
            amount_out : arg5,
        };
        0x2::event::emit<SwapEvent<T0>>(v0);
    }
    
    fun emit_whitelist_event(arg0: address, arg1: bool) {
        let v0 = WhitelistUpdatedEvent{
            addr           : arg0, 
            is_whitelisted : arg1,
        };
        0x2::event::emit<WhitelistUpdatedEvent>(v0);
    }
    
    fun get_amount_for_add_liquidity<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: u64, arg2: u64, arg3: u64, arg4: u64) : (u64, u64) {
        let (v0, v1, _) = get_reserves<T0, T1>(arg0);
        if (v1 == 0 && v0 == 0) {
            (arg1, arg2)
        } else {
            let v5 = get_token_amount_to_maintain_ratio(arg1, v1, v0);
            let (v6, v7) = if (v5 <= arg2) {
                assert!(v5 >= arg4, 4);
                (arg1, v5)
            } else {
                let v8 = get_token_amount_to_maintain_ratio(arg2, v0, v1);
                assert!(v8 <= arg1, 6);
                assert!(v8 >= arg3, 5);
                (v8, arg2)
            };
            (v6, v7)
        }
    }
    
    fun get_fee_from_protocol_configs(arg0: &ProtocolConfigs, arg1: bool) : (u64, u64) {
        if (arg1) {
            (arg0.lp_fee_percent_stable, arg0.protocol_fee_percent_stable)
        } else {
            (arg0.lp_fee_percent_uc, arg0.protocol_fee_percent_uc)
        }
    }
    
    public fun get_reserves<T0, T1>(arg0: &Pool<T0, T1>) : (u64, u64, u64) {
        (sui::balance::value<T1>(&arg0.token_y), sui::balance::value<T0>(&arg0.token_x), sui::balance::supply_value<LSP<T0, T1>>(&arg0.lsp_supply))
    }
    
    fun get_scale_from_coinmetadata<T0>(arg0: &sui::coin::CoinMetadata<T0>) : u64 {
        0x2::math::pow(10, sui::coin::get_decimals<T0>(arg0))
    }
    
    fun get_token_amount_to_maintain_ratio(arg0: u64, arg1: u64, arg2: u64) : u64 {
        assert!(arg0 > 0, 18);
        assert!(arg1 > 0 && arg2 > 0, 19);
        (kriya::safe_math::safe_mul_div_u64(arg0, arg2, arg1) as u64)
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = 0x2::table::new<address, bool>(arg0);
        0x2::table::add<address, bool>(&mut v0, sui::tx_context::sender(arg0), true);
        let v1 = ProtocolConfigs{
            id                          : sui::object::new(arg0), 
            protocol_fee_percent_uc     : 0, 
            lp_fee_percent_uc           : 0, 
            protocol_fee_percent_stable : 0, 
            lp_fee_percent_stable       : 0, 
            is_swap_enabled             : true, 
            is_deposit_enabled          : true, 
            is_withdraw_enabled         : true, 
            admin                       : sui::tx_context::sender(arg0), 
            whitelisted_addresses           : v0,
        };
        emit_whitelist_event(sui::tx_context::sender(arg0), true);
        0x2::transfer::share_object<ProtocolConfigs>(v1);
    }
    
    fun mint_lsp_token<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::balance::Balance<T0>, arg2: sui::balance::Balance<T1>, arg3: &mut sui::tx_context::TxContext) : sui::coin::Coin<LSP<T0, T1>> {
        let (v0, v1, _) = get_reserves<T0, T1>(arg0);
        let v3 = sui::balance::supply_value<LSP<T0, T1>>(&arg0.lsp_supply);
        let v4 = if (v3 == 0) {
            let v5 = (0x2::math::sqrt_u128((sui::balance::value<T0>(&arg1) as u128) * (sui::balance::value<T1>(&arg2) as u128)) as u64);
            assert!(v5 > 1000, 14);
            sui::balance::join<LSP<T0, T1>>(&mut arg0.lsp_locked, sui::balance::increase_supply<LSP<T0, T1>>(&mut arg0.lsp_supply, 1000));
            v5 - 1000
        } else {
            0x2::math::min(kriya::safe_math::safe_mul_div_u64(sui::balance::value<T0>(&arg1), v3, v1), kriya::safe_math::safe_mul_div_u64(sui::balance::value<T1>(&arg2), v3, v0))
        };
        assert!(v4 > 0, 7);
        sui::balance::join<T0>(&mut arg0.token_x, arg1);
        sui::balance::join<T1>(&mut arg0.token_y, arg2);
        sui::coin::from_balance<LSP<T0, T1>>(sui::balance::increase_supply<LSP<T0, T1>>(&mut arg0.lsp_supply, v4), arg3)
    }
    
    public fun remove_liquidity<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: KriyaLPToken<T0, T1>, arg2: u64, arg3: &mut sui::tx_context::TxContext) : (sui::coin::Coin<T1>, sui::coin::Coin<T0>) {
        assert!(arg0.is_withdraw_enabled, 12);
        assert!(arg1.pool_id == *uid_as_inner(&arg0.id), 20);
        assert!(arg2 > 0, 0);
        assert!(sui::coin::value<LSP<T0, T1>>(&arg1.lsp) >= arg2, 3);
        let (v0, v1, v2) = get_reserves<T0, T1>(arg0);
        let v3 = kriya::safe_math::safe_mul_div_u64(v0, arg2, v2);
        let v4 = kriya::safe_math::safe_mul_div_u64(v1, arg2, v2);
        assert!(v3 > 0 && v4 > 0, 0);
        sui::balance::decrease_supply<LSP<T0, T1>>(&mut arg0.lsp_supply, sui::coin::into_balance<LSP<T0, T1>>(sui::coin::split<LSP<T0, T1>>(&mut arg1.lsp, arg2, arg3)));
        if (sui::coin::value<LSP<T0, T1>>(&arg1.lsp) == 0) {
            let KriyaLPToken {
                id      : v5,
                pool_id : _,
                lsp     : v7,
            } = arg1;
            sui::object::delete(v5);
            sui::coin::destroy_zero<LSP<T0, T1>>(v7);
        } else {
            0x2::transfer::transfer<KriyaLPToken<T0, T1>>(arg1, sui::tx_context::sender(arg3));
        };
        emit_liquidity_removed_event(*uid_as_inner(&arg0.id), sui::tx_context::sender(arg3), v4, v3, arg2);
        (sui::coin::take<T1>(&mut arg0.token_y, v3, arg3), sui::coin::take<T0>(&mut arg0.token_x, v4, arg3))
    }
    
    public entry fun remove_liquidity_<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: KriyaLPToken<T0, T1>, arg2: u64, arg3: &mut sui::tx_context::TxContext) {
        let (v0, v1) = remove_liquidity<T0, T1>(arg0, arg1, arg2, arg3);
        let v2 = sui::tx_context::sender(arg3);
        0x2::transfer::public_transfer<sui::coin::Coin<T1>>(v0, v2);
        0x2::transfer::public_transfer<sui::coin::Coin<T0>>(v1, v2);
    }
    
    public entry fun remove_whitelisted_address_config(arg0: &mut ProtocolConfigs, arg1: address, arg2: &mut sui::tx_context::TxContext) {
        assert!(arg0.admin == sui::tx_context::sender(arg2), 10);
        assert!(arg0.admin != arg1, 15);
        assert!(0x2::table::contains<address, bool>(&arg0.whitelisted_addresses, arg1), 13);
        0x2::table::remove<address, bool>(&mut arg0.whitelisted_addresses, arg1);
        emit_whitelist_event(arg1, false);
    }
    
    public entry fun set_pause_config(arg0: &mut ProtocolConfigs, arg1: bool, arg2: bool, arg3: bool, arg4: &mut sui::tx_context::TxContext) {
        assert!(0x2::table::contains<address, bool>(&arg0.whitelisted_addresses, sui::tx_context::sender(arg4)), 9);
        arg0.is_swap_enabled = arg1;
        arg0.is_deposit_enabled = arg2;
        arg0.is_withdraw_enabled = arg3;
        emit_config_updated_event(arg0);
    }
    
    public entry fun set_stable_fee_config(arg0: &mut ProtocolConfigs, arg1: u64, arg2: u64, arg3: &mut sui::tx_context::TxContext) {
        assert!(0x2::table::contains<address, bool>(&arg0.whitelisted_addresses, sui::tx_context::sender(arg3)), 9);
        assert!(arg1 + arg2 <= (1000000 as u64), 17);
        arg0.lp_fee_percent_stable = arg1;
        arg0.protocol_fee_percent_stable = arg2;
        emit_config_updated_event(arg0);
    }
    
    public entry fun set_uc_fee_config(arg0: &mut ProtocolConfigs, arg1: u64, arg2: u64, arg3: &mut sui::tx_context::TxContext) {
        assert!(0x2::table::contains<address, bool>(&arg0.whitelisted_addresses, sui::tx_context::sender(arg3)), 9);
        assert!(arg1 + arg2 <= (1000000 as u64), 17);
        arg0.lp_fee_percent_uc = arg1;
        arg0.protocol_fee_percent_uc = arg2;
        emit_config_updated_event(arg0);
    }
    
    public entry fun set_whitelisted_address_config(arg0: &mut ProtocolConfigs, arg1: address, arg2: &mut sui::tx_context::TxContext) {
        assert!(arg0.admin == sui::tx_context::sender(arg2), 10);
        assert!(!0x2::table::contains<address, bool>(&arg0.whitelisted_addresses, arg1), 13);
        0x2::table::add<address, bool>(&mut arg0.whitelisted_addresses, arg1, true);
        emit_whitelist_event(arg1, true);
    }
    
    // public fun swap_token_x<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::coin::Coin<T0>, arg2: u64, arg3: u64, arg4: &mut sui::tx_context::TxContext) : sui::coin::Coin<T1> {
    //     assert!(arg0.is_swap_enabled, 11);
    //     let v0 = sui::coin::value<T0>(&arg1);
    //     assert!(arg2 > 0, 0);
    //     assert!(v0 >= arg2, 3);
    //     0x2::transfer::public_transfer<sui::coin::Coin<T0>>(sui::coin::split<T0>(&mut arg1, v0 - arg2, arg4), sui::tx_context::sender(arg4));
    //     let v1 = sui::coin::into_balance<T0>(arg1);
    //     let (v2, v3, _) = get_reserves<T0, T1>(arg0);
    //     assert!(v2 > 0 && v3 > 0, 2);
    //     let v5 = (((sui::balance::value<T0>(&v1) as u128) * (arg0.protocol_fee_percent as u128) / (1000000 as u128)) as u64);
    //     let v6 = if (arg0.is_stable) {
    //         kriya::utils::get_input_price_stable(arg2 - v5, v3, v2, arg0.lp_fee_percent, arg0.scaleX, arg0.scaleY)
    //     } else {
    //         kriya::utils::get_input_price_uncorrelated(arg2 - v5, v3, v2, arg0.lp_fee_percent)
    //     };
    //     assert!(v6 >= arg3, 8);
    //     sui::balance::join<T0>(&mut arg0.token_x, v1);
    //     sui::balance::join<T0>(&mut arg0.protocol_fee_x, sui::coin::into_balance<T0>(sui::coin::take<T0>(&mut v1, v5, arg4)));
    //     let (v7, v8, _) = get_reserves<T0, T1>(arg0);
    //     assert_lp_value_is_increased(arg0.is_stable, arg0.scaleX, arg0.scaleY, (v3 as u128), (v2 as u128), (v8 as u128), (v7 as u128));
    //     emit_swap_event<T0>(*uid_as_inner(&arg0.id), sui::tx_context::sender(arg4), v8, v7, arg2 - v5, v6);
    //     sui::coin::take<T1>(&mut arg0.token_y, v6, arg4)
    // }
    
    // public entry fun swap_token_x_<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::coin::Coin<T0>, arg2: u64, arg3: u64, arg4: &mut sui::tx_context::TxContext) {
    //     0x2::transfer::public_transfer<sui::coin::Coin<T1>>(swap_token_x<T0, T1>(arg0, arg1, arg2, arg3, arg4), sui::tx_context::sender(arg4));
    // }
    
    // public fun swap_token_y<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::coin::Coin<T1>, arg2: u64, arg3: u64, arg4: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
    //     assert!(arg0.is_swap_enabled, 11);
    //     let v0 = sui::coin::value<T1>(&arg1);
    //     assert!(arg2 > 0, 0);
    //     assert!(v0 >= arg2, 3);
    //     0x2::transfer::public_transfer<sui::coin::Coin<T1>>(sui::coin::split<T1>(&mut arg1, v0 - arg2, arg4), sui::tx_context::sender(arg4));
    //     let v1 = sui::coin::into_balance<T1>(arg1);
    //     let (v2, v3, _) = get_reserves<T0, T1>(arg0);
    //     assert!(v2 > 0 && v3 > 0, 2);
    //     let v5 = (((sui::balance::value<T1>(&v1) as u128) * (arg0.protocol_fee_percent as u128) / 1000000) as u64);
    //     let v6 = if (arg0.is_stable) {
    //         kriya::utils::get_input_price_stable(arg2 - v5, v2, v3, arg0.lp_fee_percent, arg0.scaleY, arg0.scaleX)
    //     } else {
    //         kriya::utils::get_input_price_uncorrelated(arg2 - v5, v2, v3, arg0.lp_fee_percent)
    //     };
    //     assert!(v6 >= arg3, 8);
    //     sui::balance::join<T1>(&mut arg0.token_y, v1);
    //     sui::balance::join<T1>(&mut arg0.protocol_fee_y, sui::coin::into_balance<T1>(sui::coin::take<T1>(&mut v1, v5, arg4)));
    //     let (v7, v8, _) = get_reserves<T0, T1>(arg0);
    //     assert_lp_value_is_increased(arg0.is_stable, arg0.scaleX, arg0.scaleY, (v3 as u128), (v2 as u128), (v8 as u128), (v7 as u128));
    //     emit_swap_event<T1>(*uid_as_inner(&arg0.id), sui::tx_context::sender(arg4), v8, v7, arg2 - v5, v6);
    //     sui::coin::take<T0>(&mut arg0.token_x, v6, arg4)
    // }
    
    // public entry fun swap_token_y_<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: sui::coin::Coin<T1>, arg2: u64, arg3: u64, arg4: &mut sui::tx_context::TxContext) {
    //     0x2::transfer::public_transfer<sui::coin::Coin<T0>>(swap_token_y<T0, T1>(arg0, arg1, arg2, arg3, arg4), sui::tx_context::sender(arg4));
    // }
    
    public entry fun update_fees<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: &ProtocolConfigs, arg2: &mut sui::tx_context::TxContext) {
        assert!(0x2::table::contains<address, bool>(&arg1.whitelisted_addresses, sui::tx_context::sender(arg2)), 9);
        if (arg0.is_stable) {
            arg0.lp_fee_percent = arg1.lp_fee_percent_stable;
            arg0.protocol_fee_percent = arg1.protocol_fee_percent_stable;
        } else {
            arg0.lp_fee_percent = arg1.lp_fee_percent_uc;
            arg0.protocol_fee_percent = arg1.protocol_fee_percent_uc;
        };
        emit_pool_updated_event<T0, T1>(arg0);
    }
    
    public entry fun update_pool<T0, T1>(arg0: &mut Pool<T0, T1>, arg1: &ProtocolConfigs, arg2: &mut sui::tx_context::TxContext) {
        if (arg0.is_stable) {
            arg0.lp_fee_percent = arg1.lp_fee_percent_stable;
            arg0.protocol_fee_percent = arg1.protocol_fee_percent_stable;
        } else {
            arg0.lp_fee_percent = arg1.lp_fee_percent_uc;
            arg0.protocol_fee_percent = arg1.protocol_fee_percent_uc;
        };
        arg0.is_swap_enabled = arg1.is_swap_enabled;
        arg0.is_deposit_enabled = arg1.is_deposit_enabled;
        arg0.is_withdraw_enabled = arg1.is_withdraw_enabled;
        emit_pool_updated_event<T0, T1>(arg0);
    }
    
    // decompiled from Move bytecode v6
}

