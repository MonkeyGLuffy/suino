#[test_only]
module suino::random_test{
    // use sui::test_scenario::{Self as test,next_tx,ctx};
    use sui::ecdsa_k1;
    use suino::random::{Self};
    use suino::utils;
    // use suino::core::{Self,Ownership};
    // use std::debug;
    
 
    // #[test]
    // fun test_random(){
    //     let owner = @0xC0FFEE;
    //     let user = @0xA1;
    //     let scenario_val = test::begin(user);
    //     let scenario = &mut scenario_val;
    //     //init
    //     next_tx(scenario,owner);
    //     {   
    //         random::test_init(ctx(scenario));
    //     };

    //     // get_random_hash test
    //     next_tx(scenario,owner);
    //     {
    //     let random = test::take_shared<Random>(scenario);
    //     let owner_hash = b"casino";
    //     let user_hash = ecdsa::keccak256(&b"suino");
    //     let compare_hash = utils::vector_combine(owner_hash,user_hash);

    //     let random_hash = random::get_hash(&random);
    //     assert!(compare_hash == random_hash,0);
    //     test::return_shared(random);
    //     };

    //     //set_random test
    //     next_tx(scenario,owner);
    //     {
    //       let random = test::take_shared<Random>(scenario);
    //       let now_random_hash = random::get_hash(&random);
    //       let ownership = test::take_from_sender<Ownership>(scenario);
    //       random::set_salt(&ownership,&mut random,b"hello");
    //       assert!(now_random_hash != random::get_hash(&random),0);
    //       test::return_shared(random);
    //       test::return_to_sender(scenario,ownership);
    //     };

    //     next_tx(scenario,user);
    //     {
    //         let random = test::take_shared<Random>(scenario);
    //         let now_random_hash = random::get_hash(&random);
    //         random::game_set_random(&mut random,ctx(scenario));
    //         assert!(now_random_hash != random::get_hash(&random),0);
    //         test::return_shared(random);
    //     };

    //     test::end(scenario_val);
    // }
    #[test]
    fun test_random(){
        let random = random::create();       
        let owner_hash = b"casino";
        let user_hash = ecdsa_k1::keccak256(&b"suino");
        let compare_hash = utils::vector_combine_hasing(owner_hash,user_hash);
 
        let random_hash = random::get_hash(&random);
        assert!(compare_hash == random_hash,0);
        random::destroy_random(random);
    }
}