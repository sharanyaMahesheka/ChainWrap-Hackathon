// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract NFTLending {
    uint public TokenId;
    uint public LoanId;
    uint public OfferId;
    uint public CreditScore;
    uint public Time;

    struct LoanMetadata {
        address borrower;
        uint token_id;
        uint shares_locked;
        uint amount_asked;
        uint security_deposit;
        uint loan_period;
        uint listing_timestamp;
    }

    enum LoanStatus {
        OPEN,
        ACTIVE,
        CLOSED,
        CANCELLED
    }

    struct LoanStats {
        uint start_timestamp;
        uint raised;
        uint limit_left;
        uint interest;
        uint repaid;
        LoanStatus loan_status;
    }

    enum OfferStatus {
        PENDING,
        ACCEPTED,
        REJECTED,
        WITHDRAWN
    }

    
    struct NewLoanAd {
        uint loan_id;
        address borrower;
    }

    event NewLoanAdEvent(
        uint indexed loan_id,
        address indexed borrower
    );

    
    struct OfferMetadata {
        address lender;
        uint amount;
        uint interest;
        OfferStatus status;
    }

    enum Error {
        InsufficientSecurityDeposit,
        FractionalNftTransferFailed,
        ActiveOfferAlreadyExists,
        ExcessiveLendingAmountSent,
        NotOfferPhase,
        NotCooldownPhase,
        NoOfferExists,
        WithdrawFailed,
        InvalidLoanId,
        InvalidOfferId,
        LoanIsNotOpen,
        LoanIsNotActive,
        LoanHasNotExpired,
        LoanHasExpired,
        LoanRepaymentPeriodAlreadyOver,
        NotAuthorized,
        ZeroValue,
        OfferNotInPendingState,
        LoanLimitExceeding,
        OfferIsNotAccepted
    }

//}
    //contract LendingLogic {
        address public admin;
        address public fractionalizer;
        uint public loan_nonce;
        uint public offer_phase_duration;
        uint public cooldown_phase_duration;

        mapping(address => uint) credit_score;
        mapping(uint => LoanMetadata) public loans;
        mapping(uint => LoanStats) public loan_stats;
        
        mapping(uint => uint) public offers_nonce;
        mapping(uint => mapping(uint => OfferMetadata)) public offers;
        mapping(uint => mapping(address => uint)) public active_offer_id;
        
        constructor(address _fractionalizer, uint _offer_phase_duration, uint _cooldown_phase_duration) {

            admin = msg.sender;
            fractionalizer = _fractionalizer;
            loan_nonce = 0;
            offer_phase_duration = _offer_phase_duration;
            cooldown_phase_duration = _cooldown_phase_duration;
        }

        // Function to support receiving single ERC1155 token transfer
        function signal_erc1155_support (address operator) public view returns (bytes memory) {
                require(operator == msg.sender);
                return hex"00";
                //return hex"xF20x3A0x6E0x61";
            }
        // Function to withdraw an existing offer made by a lender for a loan
        // @param loan_id: The ID of the loan
        // @return: The ID of the withdrawn offer if successful, otherwise an error is returned
        function withdraw_offer(uint loan_id) public returns (uint) {
            // Get the caller's address
            address caller = msg.sender;

            // Get the loan metadata and statistics
            LoanMetadata memory loan_metadata = loans[loan_id];
            LoanStats memory loan_stats_0 = loan_stats[loan_id];

            // Check if the loan is currently in the offer phase
            require(
                ref_is_offer_phase(loan_metadata, loan_stats_0),
                "Not in the offer phase"
            );

            // Get the ID of the active offer made by the caller for the loan
            OfferId = active_offer_id[loan_id][caller];
            OfferMetadata memory offer = offers[loan_id][OfferId];

            // Ensure that the offer is in the PENDING state
            require(
                offer.status == OfferStatus.PENDING,
                "Offer is not in the pending state"
            );

            // @discuss: Should we deduct some handling fee to avoid spam
            // Transfer the offered amount back to the lender
            if (!payable(caller).send(offer.amount)) {
                revert("Withdraw failed");
            }

            // Mark the offer as WITHDRAWN
            offer.status = OfferStatus.WITHDRAWN;
            offers[loan_id][OfferId] = offer;
            delete active_offer_id[loan_id][caller];

            // Return the ID of the withdrawn offer
            return OfferId;
        }

        // Function for the borrower to respond to a lender's offer for a loan
        // @param loan_id: The ID of the loan
        // @param offer_id: The ID of the lender's offer
        // @param response: The borrower's response to the offer (true = accepted, false = rejected)
        // @return: Ok() if the operation is successful, otherwise an error is returned
        function respond_to_offer(uint loan_id, uint offer_id, bool response) public  {
            // Get the caller's address (borrower)
            address caller = msg.sender;

            // Get the loan metadata and statistics
            LoanMetadata storage loan_metadata = loans[loan_id];
            LoanStats storage loan_stats_1 = loan_stats[loan_id];

            // Check if the caller is the borrower of the loan
            require(
                caller == loan_metadata.borrower,
                "Not authorized to respond to the offer"
            );

            // Check if the loan is currently in the open status
            require(
                loan_stats_1.loan_status == LoanStatus.OPEN,
                "Loan is not open for responses"
            );

            // Check if the loan has not expired (within the cooldown period)
            uint time = block.timestamp;
            uint cooldown_time = loan_metadata.listing_timestamp + offer_phase_duration + cooldown_phase_duration;
            require(
                time <= cooldown_time,
                "Loan has expired and is not accepting responses"
            );

            // Get the details of the lender's offer for the loan
            OfferMetadata storage offer = offers[loan_id][offer_id];

            // Check if the offer is in the PENDING state
            require(
                offer.status == OfferStatus.PENDING,
                "Offer is not in the pending state"
            );

            // Respond to the offer based on the borrower's decision
            if (response == false) {
                // If the borrower rejects the offer, call the ref_reject_offer function
                ref_reject_offer(loan_id, offer_id, offer);
            } else {
                // If the borrower accepts the offer
                // Check if the offered amount does not exceed the remaining loan limit
                require(
                    offer.amount <= loan_stats_1.limit_left,
                    "Offer amount exceeds the remaining loan limit"
                );

                // Update the offer status to ACCEPTED
                offer.status = OfferStatus.ACCEPTED;
                offers[loan_id][offer_id] = offer;

                // Update the loan statistics with the accepted offer details
                loan_stats_1.raised += offer.amount;
                loan_stats_1.limit_left -= offer.amount;
                loan_stats_1.interest += offer.interest;

                // Check if the loan limit is fully utilized
                if (loan_stats_1.limit_left == 0) {
                    // If the loan limit is fully utilized, start the loan (mark it as ACTIVE)
                    ref_start_loan(loan_id, loan_stats_1, caller);
                } else {
                    // If there is still available loan limit, update the loan statistics
                    loan_stats[loan_id] = loan_stats_1;
                }
            }

            // Return Ok() to indicate the successful completion of the function
        }

        // Function to list an advertisement for a loan
        // @param token_id: The identifier of the token to be used as collateral (TokenId)
        // @param shares_to_lock: The number of shares to be locked as collateral (Balance)
        // @param amount_asked: The amount asked for the loan (Balance)
        // @param loan_period: The duration of the loan in seconds (Time)
        // @return: The LoanId of the newly listed loan
        function list_advertisement(uint token_id, uint shares_to_lock, uint amount_asked, uint loan_period) public payable returns (uint) {
            
            // Get the address of the caller
            address caller = msg.sender;

            require(amount_asked > 0, "ZeroValue");

            // Ensure sufficient security-deposit is transferred
            uint required_deposit = get_collateral_required(caller, amount_asked, loan_period);
            require(msg.value >= required_deposit, "InsufficientSecurityDeposit");

            // Lock the shares of the token (safe_transfer_from)
            // Implement the logic to transfer fractional NFT here

            LoanMetadata memory loan_metadata = LoanMetadata({
                borrower: caller,
                token_id: token_id,
                shares_locked: shares_to_lock,
                amount_asked: amount_asked,
                security_deposit: msg.value,
                loan_period: loan_period,
                listing_timestamp: block.timestamp
            });

            LoanStats memory loan_stats_2 = LoanStats({
                start_timestamp: 0,
                raised: 0,
                limit_left: amount_asked,
                interest: 0,
                repaid: 0,
                loan_status: LoanStatus.OPEN
            });

            loan_nonce++;
            loans[loan_nonce] = loan_metadata;
            loan_stats[loan_nonce] = loan_stats_2;

            emit NewLoanAdEvent(loan_nonce, caller);

            return loan_nonce;
        }

        function start_loan(uint loan_id) public {
            address caller = msg.sender;

            // Fetch the loan metadata and loan stats from the respective mappings
            LoanMetadata storage loan_metadata = loans[loan_id];
            LoanStats storage loan_stats_3 = loan_stats[loan_id];

            require(caller == loan_metadata.borrower, "NotAuthorized");
            require(loan_stats_3.loan_status == LoanStatus.OPEN, "LoanIsNotOpen");
            require(loan_stats_3.raised > 0, "ZeroValue");

            // Calculate the cooldown time
            uint time = uint(block.timestamp);
            uint cooldown_time = loan_metadata.listing_timestamp + offer_phase_duration + cooldown_phase_duration;
            require(time <= cooldown_time, "LoanHasExpired");

            // Call the internal function to start the loan
            ref_start_loan(loan_id, loan_stats_3, caller);

            // Emit the NewLoanAd event (assuming you have the LoanId as an indexed parameter)
        }

        // Function to cancel a loan
        function cancel_loan(uint loan_id) public {
            address caller = msg.sender;

            // Fetch the loan metadata and loan stats from the respective mappings
            LoanMetadata storage loan_metadata = loans[loan_id];
            LoanStats storage loan_stats_4 = loan_stats[loan_id];

            uint time = uint(block.timestamp);
            uint cooldown_time = loan_metadata.listing_timestamp + offer_phase_duration + cooldown_phase_duration;

            // If the cooldown_time has not elapsed, only the borrower can cancel the loan
            require(time > cooldown_time || caller == loan_metadata.borrower, "NotAuthorized");
            require(loan_stats_4.loan_status == LoanStatus.OPEN, "LoanIsNotOpen");

            // Calculate the cancellation charges and the amount to be refunded to the borrower
            uint cancellation_charges = get_cancellation_charges();
            uint amount = loan_metadata.security_deposit - cancellation_charges;

            // Transfer the refund amount to the borrower
            // Assuming the 'amount' is held in the contract's balance
            if (amount > 0 && !payable(loan_metadata.borrower).send(amount)) {
                revert("WithdrawFailed");
            }

            // Call the internal function to reject all offers
            ref_reject_all_offers(loan_id);

            // Call the internal function to unlock the shares
            transfer_fractional_nft();

            // Update the loan status to 'CANCELLED'
            loan_stats_4.loan_status = LoanStatus.CANCELLED;
            loan_stats[loan_id] = loan_stats_4;

        }

        // Function to get the cancellation charges for a loan
        // @return: The cancellation charges in the smallest unit of the currency (Balance)
        function get_cancellation_charges() public pure returns (uint) {
            // Set the number of decimals for the charges
            uint decimals = 6;

            // Set the charges value (1)
            uint charges = 1;

            // Calculate the cancellation charges by multiplying the charges value by 10^decimals
            return charges * 10**uint(decimals);
        }

        // Function to repay a loan
        function repay_loan(uint loan_id) public payable  {
            // Fetch the loan metadata and loan stats from the respective mappings
            LoanMetadata storage loan_metadata = loans[loan_id];
            LoanStats storage loan_stats_5 = loan_stats[loan_id];

            // Check if the loan is active
            require(loan_stats_5.loan_status == LoanStatus.ACTIVE, "LoanIsNotActive");

            uint time = uint(block.timestamp);
            uint loan_expiry = loan_stats_5.start_timestamp + loan_metadata.loan_period;
            
            // Check if the loan repayment period is still ongoing
            require(time <= loan_expiry, "LoanRepaymentPeriodAlreadyOver");

            // Increment the amount repaid with the transferred value
            loan_stats_5.repaid += uint(msg.value);

            // Check if the loan has been fully repaid with interest
            if (loan_stats_5.repaid >= loan_stats_5.raised + loan_stats_5.interest) {
                // Call the internal function to settle the loan
                ref_settle_loan(loan_id, loan_metadata, loan_stats_5);
                
                // Call the internal function to increment the credit score of the borrower
                inc_credit_score(loan_metadata.borrower);

                // Update the loan status to 'CLOSED'
                loan_stats_5.loan_status = LoanStatus.CLOSED;
            }

            // Update the loan_stats mapping with the updated loan_stats
            loan_stats[loan_id] = loan_stats_5;
        }

        // Function to claim a loan as default by the borrower
        // @param loan_id: The identifier of the loan to be claimed as default
        // @return: A Result indicating success or failure of the operation
        function claim_loan_default(uint loan_id) public {
            // Get the loan metadata and stats from their respective mappings
            LoanMetadata storage loan_metadata = loans[loan_id];
            LoanStats storage loan_stats_6 = loan_stats[loan_id];

            // Ensure the loan status is ACTIVE; otherwise, it cannot be claimed as default
            require(loan_stats_6.loan_status == LoanStatus.ACTIVE, "Loan is not active");

            // Get the current block timestamp
            uint time = block.timestamp;

            // Calculate the loan expiry time (start timestamp + loan period)
            uint loan_expiry = loan_stats_6.start_timestamp + loan_metadata.loan_period;

            // Ensure the current time has passed the loan expiry time; otherwise, it cannot be claimed as default
            require(time > loan_expiry, "Loan has not expired");

            // Call the function to settle the loan as it has defaulted
            ref_settle_loan(loan_id, loan_metadata, loan_stats_6);

            // Reduce the credit score of the borrower
            dec_credit_score(loan_metadata.borrower);

            // Set the loan status to CLOSED as it has been claimed as default
            loan_stats_6.loan_status = LoanStatus.CLOSED;

            // Update the loan stats in the mapping
            loan_stats[loan_id] = loan_stats_6;
        }

        // Function to make a lending offer for a specific loan
        // @param loan_id: The identifier of the loan to make the offer for
        // @param interest: The amount of interest to be offered by the lender
        // @return offer_id: The identifier of the newly created offer
        function make_offer(uint loan_id, uint interest) public payable returns (uint offer_id) {
            // Get the address of the caller making the offer
            address caller = msg.sender;

            // Get the amount sent with the transaction, which represents the lending amount
            uint amount = msg.value;
            require(amount > 0, "ZeroValue: No value sent with the transaction");

            // Get the metadata and stats of the loan
            LoanMetadata memory loan_metadata = loans[loan_id];
            LoanStats memory loan_stats_7 = loan_stats[loan_id];

            // Check if the offer phase is still active for the loan
            ref_is_offer_phase(loan_metadata, loan_stats_7);

            // Check if the caller has already made an active offer for the loan
            require(active_offer_id[loan_id][caller] == 0, "ActiveOfferAlreadyExists: You have already made an active offer for this loan");

            // Check if the lending amount does not exceed the remaining limit for the loan
            require(amount <= loan_stats_7.limit_left, "ExcessiveLendingAmountSent: Lending amount exceeds the remaining limit for this loan");

            // Generate a new offer_id for the offer
            offer_id = offers_nonce[loan_id];
            

            // Create the offer with the provided details and set its status to PENDING
            OfferMetadata memory offer = OfferMetadata({
                lender: caller,
                amount: amount,
                interest: interest,
                status: OfferStatus.PENDING
            });

            // Add the offer to the offers mapping and mark it as an active offer for the loan
            offers[loan_id][offer_id] = offer;
            active_offer_id[loan_id][caller] = offer_id;
            offers_nonce[loan_id] = offer_id + 1;

            // Emit an event to notify the creation of the offer

            return offer_id;
        }

        // Function to check if the loan is currently in the offer phase
        // @param loan_id: The identifier of the loan to check
        // @return: Success if the loan is in the offer phase, otherwise an error is returned
        function is_offer_phase(uint loan_id) public view returns (bool) {
            // Get the metadata and stats of the loan
            LoanMetadata memory loan_metadata = loans[loan_id];
            LoanStats memory loan_stats_8 = loan_stats[loan_id];

            // Call the internal function ref_is_offer_phase to perform the actual check
            return ref_is_offer_phase(loan_metadata, loan_stats_8);
        }

        // Internal function to check if the loan is currently in the offer phase
        // @param loan_metadata: The metadata of the loan
        // @param loan_stats: The statistics of the loan
        // @return: Success if the loan is in the offer phase, otherwise an error is returned
        function ref_is_offer_phase(LoanMetadata memory loan_metadata, LoanStats memory loan_stats_9) internal view returns (bool) {
            // Ensure that the loan status is OPEN (in the offer phase)
            require(
                loan_stats_9.loan_status == LoanStatus.OPEN,
                "Not in the offer phase"
            );

            // Get the current time from the block timestamp
            uint current_time = block.timestamp;

            // Ensure that the current time is within the offer phase duration
            require(
                current_time <= loan_metadata.listing_timestamp + offer_phase_duration,
                "Not in the offer phase"
            );

            // Return success if the loan is in the offer phase
            return true;
        }


        function ref_start_loan(uint loan_id, LoanStats storage loan_stats_10, address borrower) internal {
            loan_stats_10.start_timestamp = uint(block.timestamp);
            loan_stats_10.loan_status = LoanStatus.ACTIVE;
            loan_stats[loan_id] = loan_stats_10;

            // Transfer the raised amount to the borrower
            // Assuming the 'raised' amount is held in the contract's balance
            if (!payable(borrower).send(loan_stats_10.raised)) {
                revert("WithdrawFailed");
            }

            // Call the internal function to reject all pending offers
            reject_all_pending_offers(loan_id);

        }

        // Function to settle a loan
        function ref_settle_loan(uint loan_id, LoanMetadata storage loan_metadata, LoanStats storage loan_stats_11) internal {
            uint total_offers = offers_nonce[loan_id];
            uint remaining_shares = loan_metadata.shares_locked;
            uint borrower_unlocked_shares = ref_get_borrower_settlement(loan_stats_11, loan_metadata.shares_locked);

            for (uint offer_id = 0; offer_id < total_offers; offer_id++) {
                OfferMetadata memory offer = offers[loan_id][offer_id];
                if (offer.status == OfferStatus.ACCEPTED) {
                    (uint funds, uint nft_shares) = ref_get_lender_settlement(loan_metadata, loan_stats_11, offer, borrower_unlocked_shares);
                    remaining_shares -= nft_shares;

                    // Transfer funds to the lender
                    require(payable(offer.lender).send(funds), "WithdrawFailed");

                    // TODO - Transfer NFT shares to the lender
                    transfer_fractional_nft();
                }
            }

            // TODO - Transfer remaining NFT shares back to the borrower
            transfer_fractional_nft();

        }
        

        // Function to reject all pending and accepted offers
        function ref_reject_all_offers(uint loan_id) internal {
            uint total_offers = offers_nonce[loan_id];

            for (uint offer_id = 0; offer_id < total_offers; offer_id++) {
                // Fetch the offer details from the respective mappings
                OfferMetadata storage offer = offers[loan_id][offer_id];

                // Check the offer status and reject the offer if it is 'PENDING' or 'ACCEPTED'
                if (offer.status == OfferStatus.PENDING || offer.status == OfferStatus.ACCEPTED) {
                    // Call the internal function to reject the offer
                    ref_reject_offer(loan_id, offer_id, offer);
                }
            }

        }

        function reject_all_pending_offers(uint loan_id) internal {
            uint total_offers = offers_nonce[loan_id];

            for (uint offer_id = 0; offer_id < total_offers; offer_id++) {
                // Fetch the offer details from the respective mappings
                OfferMetadata storage offer = offers[loan_id][offer_id];

                if (offer.status == OfferStatus.PENDING) {
                    // Call the internal function to reject the offer
                    ref_reject_offer(loan_id, offer_id, offer);
                }
            }
        }

         // Function to reject an offer
        function ref_reject_offer(uint loan_id, uint offer_id, OfferMetadata storage offer) internal  {
            // Transfer the offer amount back to the lender
            // Assuming the 'amount' is held in the contract's balance
            if (!payable(offer.lender).send(offer.amount)) {
                revert("WithdrawFailed");
            }

            // Update the offer status to 'REJECTED'
            offer.status = OfferStatus.REJECTED;

            // Remove the offer from the active_offer_id mapping
            delete active_offer_id[loan_id][offer.lender];

            // Update the offer in the offers mapping
            offers[loan_id][offer_id] = offer;

        }

        // Function to get the borrower's settlement shares
        function ref_get_borrower_settlement(LoanStats memory loan_stats_13, uint shares_locked) internal pure returns (uint) {
            if (loan_stats_13.raised == 0) {
                return shares_locked;
            }

            uint principal_repaid = loan_stats_13.repaid - loan_stats_13.interest;

            // User could have over-paid the loan amount
            if (loan_stats_13.raised < principal_repaid) {
                principal_repaid = loan_stats_13.raised;
            }

            uint shares_to_unlock = (shares_locked * principal_repaid) / loan_stats_13.raised;
            return shares_to_unlock;
        }

        function ref_get_lender_settlement(LoanMetadata memory loan_metadata, LoanStats memory loan_stats_12, OfferMetadata memory offer, uint borrower_unlocked_shares) internal pure returns (uint, uint) {
            if (loan_stats_12.raised == 0) {
                return (offer.amount, 0);
            }

            uint principal_repaid = loan_stats_12.repaid - loan_stats_12.interest;
            uint interest_repaid = loan_stats_12.repaid - principal_repaid;

            // Include security-deposit incase complete principle in not repaid by the borrower
            principal_repaid = principal_repaid + loan_metadata.security_deposit;
            if (loan_stats_12.raised < principal_repaid) {
                principal_repaid = loan_stats_12.raised;
            }

            uint interest = (interest_repaid * offer.interest) / loan_stats_12.interest;
            uint principal = (principal_repaid * offer.amount) / loan_stats_12.raised;

            uint funds = principal + interest;
            uint lenders_share = (loan_metadata.shares_locked - borrower_unlocked_shares) * offer.amount / loan_stats_12.raised;

            return (funds, lenders_share);
        }


        // Function to increase the credit score of an account
        // @param account: The address of the account whose credit score needs to be increased
        function inc_credit_score(address account) internal {
            // Get the current credit score of the account from the mapping or use default value (0)
            uint score = credit_score[account];

            if(score == 0) {
                score = 500;
            }

            // Increment the credit score by 20 points
            score += 20;

            // If the credit score exceeds the maximum limit (1000), cap it to 1000
            if (score > 1000) {
                score = 1000;
            }

            // Update the credit score in the mapping
            credit_score[account] = score;
        }

        // Function to decrease the credit score of an account by 100
        // @param account: The address of the account whose credit score will be decreased
        function dec_credit_score(address account) internal {
            // Get the current credit score of the account from the mapping
            uint score = credit_score[account];

            // Decrease the credit score by 100, using the `saturating_sub` function to prevent underflow
            score -= 100;

            // Update the credit score of the account in the mapping
            credit_score[account] = score;
        }

        // Function to transfer fractional NFT tokens from one account to another
        // @param from: The account from which the fractional NFT tokens are transferred (address)
        // @param to: The account to which the fractional NFT tokens are transferred (address)
        // @param token_id: The identifier of the fractional NFT token (TokenId)
        // @param amount: The amount of fractional NFT tokens to be transferred (Balance)
        // @return: Result indicating success or error (Ok() or an error)
        function transfer_fractional_nft() internal  pure {
            // Check if the amount is zero, in which case, return Ok()
            // if (amount == 0) {
            //     return ;
            // }

            // address from,
            // address to,
            // uint token_id,

            // @dev: This part is disabled during tests due to the use of `invoke_contract()` not being supported
            // (tests end up panicking).

            // Execute the safe transfer from the 'from' account to the 'to' account using the 'token_id' and 'amount'.
            // The `ink::env::call::build_call()` function is used to build the call to the `safeTransferFrom` function of the 'fractionalizer' contract.
            // The `ink::env::call::ExecutionInput` and `ink::env::call::Selector` are used to specify the method and arguments of the function call.
            // The result is captured in the 'result' variable.
            // The `ensure!()` macro is used to check if the result of the function call is successful.
            // If the result is not successful, it throws an error indicating that the fractional NFT transfer failed.
            // The `set_allow_reentry(true)` is used to allow reentrant calls during the execution of the function call.
            // Note: The '[0x53, 0x24, 0xD5, 0x56]' is the selector (function signature) of the 'safeTransferFrom' function in the 'fractionalizer' contract.
            // The '.push_arg()' is used to push the arguments for the function call onto the stack.
            // The '.returns::<core::result::Result<(), u8>>()' specifies the return type of the function call.
            // The '.params().invoke()' is used to invoke the function call and capture the result.

            // ensure!(result.is_ok(), Error::FractionalNftTransferFailed);

            // Return Ok() to indicate successful execution of the function
            return;
        }
        
        
        // Function to calculate the required collateral for a loan based on the borrower's credit score, loan amount, and loan period
        // @param account: The borrower's account address (AccountId)
        // @param borrow_amount: The amount requested for borrowing (Balance)
        // @param loan_period: The duration of the loan period in seconds (Time)
        // @return: The calculated collateral amount required for the loan (Balance)
        function get_collateral_required(address account, uint borrow_amount, uint loan_period) public view returns (uint) {
            // Get the borrower's credit score
            uint score = credit_score[account];

            // Check if the credit score is less than 100
            if (score < 100) {
                // If the credit score is less than 100, no collateral is required (borrow_amount is returned as collateral)
                return borrow_amount;
            }

            // Constants for the calculation
            uint DECIMALS = 10000; // Decimal factor used for percentages (1% = 1/10000)
            uint PER_DAY_CHARGE = 1; // 1/10000 unit => 0.01% per day (interest charge per day)
            uint DAY = 86400000; // Number of milliseconds in a day (24 hours)

            // Calculate the borrow percentage based on the credit score
            uint borrow_percent = (100 * (4000 - 3 * score) / score);

            // Calculate the period percentage based on the loan period
            uint period_percent = (loan_period * PER_DAY_CHARGE) / DAY;

            // Calculate the total percentage (borrow percentage + period percentage)
            // @discuss: Should we put an upper bound on it?
            uint total_percent = borrow_percent + period_percent;

            // Calculate the required collateral based on the total percentage
            uint security = (borrow_amount * total_percent) / DECIMALS;
            return security;
        }

    }
