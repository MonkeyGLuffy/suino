module suino::nft{
    
    use std::string::{Self,String};
    use sui::url::{Self,Url};
    use sui::tx_context::{Self,TxContext,sender};
    use sui::vec_map::{Self,VecMap};
    use sui::transfer;
    use sui::balance;
    use sui::object::{Self,ID,UID};
    use sui::sui::SUI;
    use sui::event;
    use sui::dynamic_field;
    use sui::coin::{Self,Coin};
    use suino::utils::{
        calculate_percent_amount
    };
    

       // For when amount paid does not match the expected.
    const EAmountIncorrect: u64 = 0;

    // For when someone tries to delist without ownership.
    const ENotOwner: u64 = 1;
    
    const ENotEnoughBalance:u64 = 2;
    
    struct NFT has key, store {
        id: UID,
        /// Name for the token
        name: String,
        /// Description of the token
        token_id:u64,
        description:String,
        /// URL for the token
        url: Url,
        // TODO: allow custom attributes
    }
    struct NFTState has key{
        id:UID,
        name:String,
        description:String,
        owner:address,
        holder:VecMap<ID,address>,
        fee:u64,
    }

    struct Ownership has key{
        id:UID,
        name:String
    }

    struct MintNFTEvent has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: String,
    }

    //marketplace
    struct Marketplace has key {
        id: UID,
        name:String,
        description:String,
        fee_percent:u8,
     
    }

    
    /// A single listing which contains the listed item and its price in [`Coin<C>`].
    struct Listing has store {
        item: NFT,
        ask: u64, // Coin<C>
        owner: address,
    }

    //depoly share object marketplace and state
    fun init(ctx:&mut TxContext){
        let state = NFTState{
            id:object::new(ctx),
            owner:sender(ctx),
            holder:vec_map::empty<ID,address>(),
            fee:10000,
            name:string::utf8(b"NFT State"),
            description:string::utf8(b"Suino NFT hold Tracking"),
        };
       
        let marketplace = Marketplace { 
            id:object::new(ctx),
            name:string::utf8(b"Suino NFT Marketplace"),
            description:string::utf8(b"NFT Collection Market"),
            fee_percent:5,
         };
        let ownership = Ownership{
            id:object::new(ctx),
            name:string::utf8(b"Suino NFT Ownership")
        };
        transfer::transfer(ownership,sender(ctx));
        transfer::share_object(marketplace);
        transfer::share_object(state);
    }

    //-------Entry---------

    public entry fun mint(
        _:&Ownership,
        state: &mut NFTState,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = sender(ctx);
        let id = object::new(ctx);
        let nft = NFT {
            id,
            name: string::utf8(name),
            token_id:total_supply(state) + 1,
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url)
        };

        vec_map::insert(&mut state.holder,object::uid_to_inner(&nft.id),sender);

        event::emit(MintNFTEvent {
            object_id: object::uid_to_inner(&nft.id),
            creator: sender,
            name: nft.name,
        });
        transfer::transfer(nft, sender);
    }


    entry fun claim_fee_membership(
        state:&mut NFTState,
        nft:&NFT,
        coin:&mut Coin<SUI>,
        ctx:&mut TxContext){

        fee_deduct(state,coin,ctx);
        let nft_id = object::id(nft);
        set_state_nft_holder(state,nft_id,sender(ctx));
    }
 

    public entry  fun transfer(
        state:&mut NFTState,
        nft:NFT,
        coin:&mut Coin<SUI>,
        recipent:address,
        ctx:&mut TxContext,
       ){
     
        fee_deduct(state,coin,ctx);
        let nft_id = object::id(&nft);
        set_state_nft_holder(state,nft_id,recipent);
        transfer::transfer(nft,recipent);
    }
    
    // Market place
    // List an item at the Marketplace.
    public entry fun list(
        marketplace: &mut Marketplace,
        item: NFT,
        ask: u64,
        ctx: &mut TxContext
    ) {
        let item_id = object::id(&item);
        let listing = Listing {
            item,
            ask,
            owner: tx_context::sender(ctx),
        };
        dynamic_field::add(&mut marketplace.id, item_id, listing);
    }

        /// Call [`delist`] and transfer item to the sender.
    public entry fun delist_and_take(
        marketplace: &mut Marketplace,
        item_id: ID,
        ctx: &mut TxContext
    ) {
        let item = delist(marketplace, item_id, ctx);
        transfer::transfer(item, tx_context::sender(ctx));
    }


    public fun delist(
        marketplace: &mut Marketplace,
        item_id: ID,
        ctx: &mut TxContext
    ): NFT {
        let Listing { item, ask: _, owner } =
        dynamic_field::remove(&mut marketplace.id, item_id);

        assert!(tx_context::sender(ctx) == owner, ENotOwner);

        item
    }


    
    public entry fun buy_and_take(
        marketplace: &mut Marketplace,
        state:&mut NFTState,
        item_id: ID,
        paid: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        
        let Listing{ item, ask, owner } =
        dynamic_field::remove(&mut marketplace.id, item_id);
        assert!(ask == coin::value(&paid), EAmountIncorrect);


        let fee_amt = calculate_percent_amount(coin::value(&paid),get_fee_percent(marketplace));
        let fee_coin = coin::split(&mut paid,fee_amt,ctx);
        transfer::transfer(fee_coin,get_owner(state));

        
        transfer::transfer(paid, owner);
     
        // let item = buy<C>(marketplace,state,item_id, paid,ctx);
        set_state_nft_holder(state, object::id(&item),sender(ctx));
        transfer::transfer(item, sender(ctx))
    }
   



    //===============NFT================
    /// Get the NFT's `name`
    public fun name(nft: &NFT): &string::String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description(nft: &NFT): &string::String {
        &nft.description
    }

    /// Get the NFT's `url`
    public fun url(nft: &NFT): &Url {
        &nft.url
    }

  

    //===========NFTState====================
    entry fun set_owner(_:&Ownership,state:&mut NFTState,new_owner:address,ctx:&mut TxContext){
        //only owner
        assert!(sender(ctx) == get_owner(state),0);

        state.owner = new_owner;
    }


    entry fun set_fee(_:&Ownership,state:&mut NFTState,amount:u64,ctx:&mut TxContext){
        assert!(sender(ctx) == get_owner(state),0);
        state.fee = amount;
    }

       
    public(friend) fun set_state_nft_holder(state:&mut NFTState,nft_id:ID,recipent:address){
        vec_map::remove<ID,address>(&mut state.holder,&nft_id);
        vec_map::insert<ID,address>(&mut state.holder,nft_id,recipent);
    }

    
    public fun get_owner(state:&NFTState):address{
        state.owner
    }

    public fun get_holder(state:&NFTState,id:&ID):address{
        let holder_point = vec_map::get(&state.holder,id);
        *holder_point
    }
    public fun get_fee(state:&NFTState):u64{
        state.fee
    }
    public fun total_supply(state:&NFTState):u64{
        vec_map::size(&state.holder)
    }

    public fun get_holders(state:&NFTState):VecMap<ID,address>{
        state.holder
    }

    //============SuinoMarketPlace=====================
    public fun get_fee_percent(market:&Marketplace):u8{
        market.fee_percent
    }

    
    //==============Utils===========================
    fun fee_deduct(state:&mut NFTState,coin:&mut Coin<SUI>,ctx:&mut TxContext){
        let coin_balance = coin::balance_mut(coin);
        let fee_amt = get_fee(state);
        assert!(balance::value(coin_balance) >=  fee_amt,ENotEnoughBalance);
        let fee_coin = coin::from_balance(balance::split(coin_balance,fee_amt),ctx);
        transfer::transfer(fee_coin,get_owner(state));
    }
    
    #[test_only]
    public fun init_for_testing(ctx:&mut TxContext){
        let state = NFTState{
            id:object::new(ctx),
            name:string::utf8(b"NFT State"),
            description:string::utf8(b"Suino NFT hold Tracking"),
            owner:tx_context::sender(ctx),
            holder:vec_map::empty<ID,address>(),
            fee:100000,
        };
       
        let marketplace = Marketplace { 
            id:object::new(ctx),
            name:string::utf8(b"Suino NFT Marketplace"),
            description:string::utf8(b"NFT Collection Market"),
            fee_percent:5,
         };
         let ownership = Ownership{
            id:object::new(ctx),
            name:string::utf8(b"Suino NFT Ownership")
         };
        transfer::transfer(ownership,sender(ctx));
        transfer::share_object(marketplace);
        transfer::share_object(state);
    }
    #[test_only]
    public fun test_mint_nft(state:&mut NFTState,recipent:address,ctx:&mut TxContext){
      let id = object::new(ctx);
      let nft = NFT{
        id,
        name:string::utf8(b"suino") ,
        token_id:1,
        description:string::utf8(b"suino"),
        url:url::new_unsafe_from_bytes(b"suino")
      };
      vec_map::insert(&mut state.holder,object::uid_to_inner(&nft.id),recipent);

      transfer::transfer(nft,recipent);
    }

}

