
/*
    
    The SUID module is a simple staking pool that allows users to stake SUI and receive SUID in return. 
    User can also stake and unstake SUI with the given validator.
    

    Functions
    1. add_liquidity: Add liquidity to the pool by transferring SUI to the pool and receiving SUID in return.
    2. remove_liquidity: Remove liquidity from the pool by burning SUID and receiving SUI in return.
    3. stake: stake the SUI with the given validator.
    4. unstake:  unstake the SUI.
    5. get_supply: Return the total supply of SUID.
    6. get_assets: Return the total amount of SUI in the pool.

*/




module suid::suid {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin,TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option;
    use sui_system::sui_system::{Self, SuiSystemState};
    use sui_system::staking_pool::{ StakedSui};


    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::assert_eq;
     #[test_only]
    use std::debug;

    //===========CONSTANTS================
     
    const FLOAT_SCALING: u64 = 1_000_000_000;

    //===========ERRORS===================
    const EAmountTooLow:u64=1;


    //===========STRUCTS==================

    // custom coin SUID
    struct SUID has drop {}
    
    // Shared pool object
    struct Pool has key {
        id: UID,
        sui: Balance<SUI>,
        treasury: TreasuryCap<SUID>,
    }

    /*
        Initialize the `Pool`  and create SUID currancy.
        witness: The SUID object that will be the witness for the pool.
        ctx: The transaction context.
    */

    #[allow(unused_function)]
    fun init(witness: SUID, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,
            b"SUID",
            b"Dacade Staked SUI",
            b"SUID is a Decade Staked SUI",
            option::none(),
            ctx
        );

        // Make metadata immutable
        transfer::public_freeze_object(metadata);

        // Create the shared pool
        transfer::share_object(Pool {
            id: object::new(ctx),
            sui: balance::zero<SUI>(),
            treasury,  
        });
    }

    //================= Entry Functions================

    /*
        Entrypoint for the `add_liquidity` method. Sends `SUID` to
        the transaction sender.
        pool: The shared pool where user want to stake sui.
        sui : SUI user want to stake.

    */
    entry fun add_liquidity_(
        pool: &mut Pool, sui: Coin<SUI>, ctx: &mut TxContext
    ) {
        let liquidity=add_liquidity(pool, sui, ctx);
        transfer::public_transfer(liquidity,tx_context::sender(ctx)
        );
    }

    /*
        Entrypoint for the `remove_liquidity` method. Transfers
        withdrawn assets (SUI) to the sender.
        pool: The shared pool where user want to unstake sui.
        suid : SUID user want to unstake.
    */
    entry fun remove_liquidity_(
        pool: &mut Pool,
        suid: Coin<SUID>,
        ctx: &mut TxContext
    ) {
        let (sui ) = remove_liquidity(pool, suid, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(sui, sender);
    }  


    //=================Internal Functions================


    /* 
        add liquidity to the `Pool` by transfer `SUID`.
        pool: The shared pool where user want to stake sui.
        sui : SUI user want to stake.
        Retrund SUID for given SUI.
    */
    public fun add_liquidity(
        pool: &mut Pool, sui: Coin<SUI>, ctx: &mut TxContext
    ): Coin<SUID> {
        is_valid_amount(coin::value(&sui));

        let sui_balance = coin::into_balance(sui);
        let sui_added = balance::value(&sui_balance);
        // Increase the supply of SUID
        let balance = balance::increase_supply(coin::supply_mut(&mut pool.treasury), sui_added);
        balance::join(&mut pool.sui, sui_balance);
        coin::from_balance(balance, ctx)
    }


    /*
        Remove liquidity from the `Pool` by burning `SUID`.
        pool: The shared pool where user want to unstake sui
        suid : SUID user want to unstake
        Returns `Coin<SUI>`.
    */
    public fun remove_liquidity (
        pool: &mut Pool,
        suid: Coin<SUID>,
        ctx: &mut TxContext
    ): Coin<SUI> {
        is_valid_amount(coin::value(&suid));
        let suid_amount = coin::value(&suid);
        balance::decrease_supply(coin::supply_mut(&mut pool.treasury), coin::into_balance(suid));
        coin::take(&mut pool.sui, suid_amount, ctx)
    }

    /*
        stake the `SUI` with the given validator.
        sui : SUI user want to stake.
        state: The state of the SUI system.
        validator_address: The address of the validator to stake with.
       
    */

    public fun stake( 
        sui: Coin<SUI>, 
        state: &mut SuiSystemState,
        validator_address: address,
        ctx: &mut TxContext

    ): Coin<SUID> {
        sui_system::request_add_stake(state, sui, validator_address, ctx);
    }

    /*
        unstake the `SUI`.
        state: The state of the SUI system.
        staked_sui: The staked SUI object.
        ctx: The transaction context.
    */

    public fun unstake(
        state: &mut SuiSystemState,
        staked_sui: StakedSui,
        ctx: &mut TxContext,
    ) {
        sui_system::request_withdraw_stake(
            state,  
            staked_sui, 
            ctx
        );
    } 
     

    /*===============View Functions===============*/
   
    // Return total supply of SUID
    public fun get_supply(pool: &Pool):  u64 {
        coin::total_supply(&pool.treasury)
    }

    // retrun total sui in pool
    public fun get_assets(pool: &Pool):u64{
        balance::value(&pool.sui)
    }


    /*==============Validation Functions===========*/

    // Check if SUI AMount has required value
    fun is_valid_amount(amount:u64)  {
        assert!(amount>= FLOAT_SCALING,EAmountTooLow)
    }


        /*============== Tests ===========*/


    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SUID {}, ctx)
    }

    #[test]
    fun test_init_pool_() {
        let owner = @0x01;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing( test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner); 
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);

            assert_eq(suid_supply, 0);
            assert_eq(amt_sui ,0);

            test_scenario::return_shared(pool)
        };

        test_scenario::end(scenario_val);
    }
    #[test]
    fun test_add_liquidity_() {
        let owner = @0x01;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner); 
        {
            init_for_testing( test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            assert_eq(suid_supply, amount);
            assert_eq(amt_sui, amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_liquidity_multiple_times() {
        let owner = @0x01;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner); 
        {
            init_for_testing( test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            assert_eq(suid_supply, amount);
            assert_eq(amt_sui, amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };
         test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            assert_eq(suid_supply, 2*amount);
            assert_eq(amt_sui, 2*amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };
        test_scenario::end(scenario_val);
    }


      #[test]
    fun test_add_liquidity_multiple_users() {
        let owner = @0x01;
        let user1 = @0x02;
        let user2 = @0x03;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner); 
        {
            init_for_testing( test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            let expected_suid_supply = coin::value(&suid_tokens);
            assert_eq(suid_supply, amount);
            assert_eq(amt_sui, amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };
         test_scenario::next_tx(scenario, user1);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            assert_eq(suid_supply, 2*amount);
            assert_eq(amt_sui, 2*amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };
         test_scenario::next_tx(scenario, user2);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
           
            assert_eq(suid_supply, 3*amount);
            assert_eq(amt_sui, 3*amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };
        test_scenario::end(scenario_val);
    }


    #[test, expected_failure(abort_code = EAmountTooLow)]
    fun test_add_liquidity_amount_too_low_() {
        let owner = @0x01;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing( test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner); 
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = FLOAT_SCALING - 1;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_coin=add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );
            coin::burn_for_testing(suid_coin);
            test_scenario::return_shared(pool)
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_liquidity_() {
        let owner = @0x01;

        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            init_for_testing( test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let coins = coin::mint_for_testing<SUI>(amount,  test_scenario::ctx(scenario));

            let suid_tokens = add_liquidity(
                pool_mut,
                coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            assert_eq(suid_supply, amount);
            assert_eq(amt_sui, amount);
            coin::burn_for_testing(suid_tokens);
            test_scenario::return_shared(pool)
        };

        test_scenario::next_tx(scenario, owner);
        {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let amount = 10*FLOAT_SCALING;

            let suid_coins = coin::mint_for_testing<SUID>(amount,  test_scenario::ctx(scenario));

            let sui = remove_liquidity(
                pool_mut,
                suid_coins,
                test_scenario::ctx(scenario)
            );

            let suid_supply = get_supply(&pool);
            let amt_sui = get_assets(&pool);
            assert_eq(suid_supply, 0);
            assert_eq(amt_sui, 0);
            coin::burn_for_testing(sui);
            test_scenario::return_shared(pool)
        };
        test_scenario::end(scenario_val);
    }
      
}



