;; Next-Generation Problem-Solving (NGPS) Platform
;; A decentralized ecosystem for collaborative problem-solving with AI assistance and incentivized solutions
;; Version: 1.0.0
;; Compatible with: Clarinet 3.x

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PROBLEM_NOT_FOUND (err u404))
(define-constant ERR_SOLUTION_NOT_FOUND (err u405))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_INVALID_PARAMETERS (err u400))
(define-constant ERR_ALREADY_VOTED (err u409))
(define-constant ERR_PROBLEM_CLOSED (err u408))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u407))
(define-constant ERR_SOLUTION_PERIOD_EXPIRED (err u406))

;; Data Variables
(define-data-var problem-counter uint u0)
(define-data-var solution-counter uint u0)
(define-data-var total-platform-tokens uint u10000000) ;; Total token supply
(define-data-var platform-fee-percentage uint u8) ;; 8% platform fee
(define-data-var min-problem-bounty uint u5000) ;; Minimum bounty in microSTX
(define-data-var solution-period uint u2016) ;; Solution submission period (~14 days)
(define-data-var voting-period uint u1008) ;; Voting period (~7 days)
(define-data-var min-solver-reputation uint u25) ;; Minimum reputation to submit solutions

;; Problem Categories
(define-constant CATEGORY_TECHNICAL u1)
(define-constant CATEGORY_SOCIAL u2)
(define-constant CATEGORY_ENVIRONMENTAL u3)
(define-constant CATEGORY_ECONOMIC u4)
(define-constant CATEGORY_HEALTHCARE u5)
(define-constant CATEGORY_EDUCATIONAL u6)
(define-constant CATEGORY_RESEARCH u7)

;; Problem Complexity Levels
(define-constant COMPLEXITY_SIMPLE u1)
(define-constant COMPLEXITY_MODERATE u2)
(define-constant COMPLEXITY_COMPLEX u3)
(define-constant COMPLEXITY_EXPERT u4)
(define-constant COMPLEXITY_REVOLUTIONARY u5)

;; Status Constants
(define-constant STATUS_OPEN u1)
(define-constant STATUS_SOLUTION_PHASE u2)
(define-constant STATUS_VOTING_PHASE u3)
(define-constant STATUS_RESOLVED u4)
(define-constant STATUS_EXPIRED u5)

;; Data Maps
(define-map problems 
    { problem-id: uint }
    {
        creator: principal,
        title: (string-ascii 128),
        description: (string-ascii 1024),
        category: uint,
        complexity: uint,
        bounty-amount: uint,
        additional-funding: uint,
        solution-deadline: uint,
        voting-deadline: uint,
        status: uint,
        solution-count: uint,
        total-votes: uint,
        winning-solution-id: (optional uint),
        ai-analysis-requested: bool,
        created-at: uint,
        resolved-at: (optional uint)
    }
)

(define-map solutions 
    { solution-id: uint }
    {
        problem-id: uint,
        solver: principal,
        title: (string-ascii 128),
        description: (string-ascii 2048),
        implementation-plan: (string-ascii 1024),
        feasibility-score: uint,
        innovation-score: uint,
        impact-potential: uint,
        resource-requirements: (string-ascii 512),
        evidence-hash: (optional (buff 32)),
        vote-score: uint,
        positive-votes: uint,
        negative-votes: uint,
        expert-endorsements: uint,
        submitted-at: uint
    }
)

(define-map solver-profiles
    { solver: principal }
    {
        name: (string-ascii 64),
        expertise-areas: (string-ascii 256),
        reputation-score: uint,
        problems-solved: uint,
        solutions-submitted: uint,
        total-bounties-earned: uint,
        collaboration-rating: uint,
        innovation-index: uint
    }
)

(define-map problem-votes
    { problem-id: uint, solution-id: uint, voter: principal }
    {
        vote-type: bool,
        vote-weight: uint,
        expertise-relevance: uint,
        voted-at: uint
    }
)

(define-map problem-funding
    { problem-id: uint, funder: principal }
    {
        amount: uint,
        funding-type: uint,
        funded-at: uint
    }
)

(define-map collaborative-teams
    { problem-id: uint, member: principal }
    {
        role: (string-ascii 64),
        contribution-percentage: uint,
        joined-at: uint,
        active: bool
    }
)

(define-map platform-tokens
    { holder: principal }
    { balance: uint }
)

(define-map ai-analysis
    { problem-id: uint }
    {
        complexity-assessment: uint,
        domain-classification: uint,
        solution-approaches: (string-ascii 512),
        success-probability: uint,
        resource-estimation: uint,
        risk-factors: (string-ascii 256),
        analyzed-at: uint
    }
)

;; Public Functions

;; Create solver profile
(define-public (create-solver-profile 
    (name (string-ascii 64))
    (expertise-areas (string-ascii 256)))
    (begin
        (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len expertise-areas) u0) ERR_INVALID_PARAMETERS)
        
        (map-set solver-profiles { solver: tx-sender }
            {
                name: name,
                expertise-areas: expertise-areas,
                reputation-score: u50,
                problems-solved: u0,
                solutions-submitted: u0,
                total-bounties-earned: u0,
                collaboration-rating: u75,
                innovation-index: u0
            }
        )
        
        ;; Grant initial platform tokens
        (map-set platform-tokens { holder: tx-sender } { balance: u500 })
        (ok true)
    )
)

;; Post a new problem
(define-public (post-problem
    (title (string-ascii 128))
    (description (string-ascii 1024))
    (category uint)
    (complexity uint)
    (bounty-amount uint)
    (solution-duration uint))
    (let 
        (
            (new-problem-id (+ (var-get problem-counter) u1))
            (solution-deadline (+ burn-block-height solution-duration))
            (voting-deadline (+ solution-deadline (var-get voting-period)))
        )
        (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= category u1) (<= category u7)) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= complexity u1) (<= complexity u5)) ERR_INVALID_PARAMETERS)
        (asserts! (>= bounty-amount (var-get min-problem-bounty)) ERR_INVALID_PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) bounty-amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (> solution-duration u0) ERR_INVALID_PARAMETERS)
        
        ;; Transfer bounty to contract
        (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
        
        (map-set problems { problem-id: new-problem-id }
            {
                creator: tx-sender,
                title: title,
                description: description,
                category: category,
                complexity: complexity,
                bounty-amount: bounty-amount,
                additional-funding: u0,
                solution-deadline: solution-deadline,
                voting-deadline: voting-deadline,
                status: STATUS_SOLUTION_PHASE,
                solution-count: u0,
                total-votes: u0,
                winning-solution-id: none,
                ai-analysis-requested: false,
                created-at: burn-block-height,
                resolved-at: none
            }
        )
        
        (var-set problem-counter new-problem-id)
        (ok new-problem-id)
    )
)

;; Submit a solution to a problem
(define-public (submit-solution
    (problem-id uint)
    (title (string-ascii 128))
    (description (string-ascii 2048))
    (implementation-plan (string-ascii 1024))
    (feasibility-score uint)
    (innovation-score uint)
    (impact-potential uint)
    (resource-requirements (string-ascii 512)))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
            (solver-profile (unwrap! (map-get? solver-profiles { solver: tx-sender }) ERR_UNAUTHORIZED))
            (new-solution-id (+ (var-get solution-counter) u1))
        )
        (asserts! (is-eq (get status problem) STATUS_SOLUTION_PHASE) ERR_PROBLEM_CLOSED)
        (asserts! (<= burn-block-height (get solution-deadline problem)) ERR_SOLUTION_PERIOD_EXPIRED)
        (asserts! (>= (get reputation-score solver-profile) (var-get min-solver-reputation)) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
        (asserts! (and (<= feasibility-score u100) (<= innovation-score u100) (<= impact-potential u100)) ERR_INVALID_PARAMETERS)
        
        (map-set solutions { solution-id: new-solution-id }
            {
                problem-id: problem-id,
                solver: tx-sender,
                title: title,
                description: description,
                implementation-plan: implementation-plan,
                feasibility-score: feasibility-score,
                innovation-score: innovation-score,
                impact-potential: impact-potential,
                resource-requirements: resource-requirements,
                evidence-hash: none,
                vote-score: u0,
                positive-votes: u0,
                negative-votes: u0,
                expert-endorsements: u0,
                submitted-at: burn-block-height
            }
        )
        
        ;; Update problem solution count
        (map-set problems { problem-id: problem-id }
            (merge problem { solution-count: (+ (get solution-count problem) u1) })
        )
        
        ;; Update solver stats
        (map-set solver-profiles { solver: tx-sender }
            (merge solver-profile {
                solutions-submitted: (+ (get solutions-submitted solver-profile) u1)
            })
        )
        
        (var-set solution-counter new-solution-id)
        (ok new-solution-id)
    )
)

;; Vote on a solution
(define-public (vote-solution 
    (problem-id uint) 
    (solution-id uint) 
    (positive-vote bool)
    (vote-weight uint)
    (expertise-relevance uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
            (solution (unwrap! (map-get? solutions { solution-id: solution-id }) ERR_SOLUTION_NOT_FOUND))
            (voter-profile (unwrap! (map-get? solver-profiles { solver: tx-sender }) ERR_UNAUTHORIZED))
        )
        (asserts! (is-eq (get status problem) STATUS_VOTING_PHASE) ERR_PROBLEM_CLOSED)
        (asserts! (<= burn-block-height (get voting-deadline problem)) ERR_PROBLEM_CLOSED)
        (asserts! (is-eq (get problem-id solution) problem-id) ERR_INVALID_PARAMETERS)
        (asserts! (not (is-eq tx-sender (get solver solution))) ERR_UNAUTHORIZED)
        (asserts! (and (<= vote-weight u10) (<= expertise-relevance u10)) ERR_INVALID_PARAMETERS)
        (asserts! (is-none (map-get? problem-votes { problem-id: problem-id, solution-id: solution-id, voter: tx-sender })) ERR_ALREADY_VOTED)
        
        (let 
            (
                (weighted-score (* vote-weight expertise-relevance))
                (reputation-multiplier (/ (get reputation-score voter-profile) u100))
                (final-score (* weighted-score reputation-multiplier))
            )
            (map-set problem-votes 
                { problem-id: problem-id, solution-id: solution-id, voter: tx-sender }
                {
                    vote-type: positive-vote,
                    vote-weight: vote-weight,
                    expertise-relevance: expertise-relevance,
                    voted-at: burn-block-height
                }
            )
            
            (map-set solutions { solution-id: solution-id }
                (merge solution {
                    vote-score: (if positive-vote 
                                   (+ (get vote-score solution) final-score)
                                   (- (get vote-score solution) final-score)),
                    positive-votes: (if positive-vote 
                                      (+ (get positive-votes solution) u1)
                                      (get positive-votes solution)),
                    negative-votes: (if positive-vote 
                                       (get negative-votes solution)
                                       (+ (get negative-votes solution) u1))
                })
            )
            
            (map-set problems { problem-id: problem-id }
                (merge problem { total-votes: (+ (get total-votes problem) u1) })
            )
            (ok true)
        )
    )
)

;; Transition problem to voting phase
(define-public (start-voting-phase (problem-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (is-eq (get status problem) STATUS_SOLUTION_PHASE) ERR_INVALID_PARAMETERS)
        (asserts! (> burn-block-height (get solution-deadline problem)) ERR_SOLUTION_PERIOD_EXPIRED)
        (asserts! (> (get solution-count problem) u0) ERR_INVALID_PARAMETERS)
        
        (map-set problems { problem-id: problem-id }
            (merge problem { status: STATUS_VOTING_PHASE })
        )
        (ok true)
    )
)

;; Resolve problem and distribute bounty
(define-public (resolve-problem (problem-id uint) (winning-solution-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
            (winning-solution (unwrap! (map-get? solutions { solution-id: winning-solution-id }) ERR_SOLUTION_NOT_FOUND))
            (total-bounty (+ (get bounty-amount problem) (get additional-funding problem)))
            (platform-fee (/ (* total-bounty (var-get platform-fee-percentage)) u100))
            (solver-reward (- total-bounty platform-fee))
            (winner (get solver winning-solution))
        )
        (asserts! (is-eq (get status problem) STATUS_VOTING_PHASE) ERR_INVALID_PARAMETERS)
        (asserts! (> burn-block-height (get voting-deadline problem)) ERR_PROBLEM_CLOSED)
        (asserts! (is-eq (get problem-id winning-solution) problem-id) ERR_INVALID_PARAMETERS)
        (asserts! (> (get total-votes problem) u2) ERR_INVALID_PARAMETERS) ;; Minimum votes required
        
        ;; Update problem status
        (map-set problems { problem-id: problem-id }
            (merge problem {
                status: STATUS_RESOLVED,
                winning-solution-id: (some winning-solution-id),
                resolved-at: (some burn-block-height)
            })
        )
        
        ;; Distribute bounty
        (try! (as-contract (stx-transfer? solver-reward tx-sender winner)))
        
        ;; Update winner's profile
        (let 
            (
                (winner-profile (unwrap! (map-get? solver-profiles { solver: winner }) ERR_UNAUTHORIZED))
                (complexity-bonus (* (get complexity problem) u10))
            )
            (map-set solver-profiles { solver: winner }
                (merge winner-profile {
                    problems-solved: (+ (get problems-solved winner-profile) u1),
                    total-bounties-earned: (+ (get total-bounties-earned winner-profile) solver-reward),
                    reputation-score: (+ (get reputation-score winner-profile) complexity-bonus),
                    innovation-index: (+ (get innovation-index winner-profile) 
                                        (get innovation-score winning-solution))
                })
            )
        )
        
        ;; Award platform tokens to winner
        (let 
            (
                (winner-tokens (default-to { balance: u0 } 
                    (map-get? platform-tokens { holder: winner })))
                (token-reward (* (get complexity problem) u50))
            )
            (map-set platform-tokens { holder: winner }
                { balance: (+ (get balance winner-tokens) token-reward) })
        )
        
        (ok true)
    )
)

;; Add additional funding to a problem
(define-public (fund-problem (problem-id uint) (funding-amount uint) (funding-type uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (not (is-eq (get status problem) STATUS_RESOLVED)) ERR_PROBLEM_CLOSED)
        (asserts! (> funding-amount u0) ERR_INVALID_PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) funding-amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (and (>= funding-type u1) (<= funding-type u3)) ERR_INVALID_PARAMETERS)
        
        ;; Transfer funding to contract
        (try! (stx-transfer? funding-amount tx-sender (as-contract tx-sender)))
        
        ;; Update problem funding
        (map-set problems { problem-id: problem-id }
            (merge problem { 
                additional-funding: (+ (get additional-funding problem) funding-amount) 
            })
        )
        
        ;; Record funding
        (map-set problem-funding { problem-id: problem-id, funder: tx-sender }
            {
                amount: funding-amount,
                funding-type: funding-type,
                funded-at: burn-block-height
            }
        )
        (ok true)
    )
)

;; Join collaborative team for a problem
(define-public (join-collaborative-team 
    (problem-id uint) 
    (role (string-ascii 64))
    (contribution-percentage uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (not (is-eq (get status problem) STATUS_RESOLVED)) ERR_PROBLEM_CLOSED)
        (asserts! (<= contribution-percentage u100) ERR_INVALID_PARAMETERS)
        (asserts! (> (len role) u0) ERR_INVALID_PARAMETERS)
        
        (map-set collaborative-teams { problem-id: problem-id, member: tx-sender }
            {
                role: role,
                contribution-percentage: contribution-percentage,
                joined-at: burn-block-height,
                active: true
            }
        )
        (ok true)
    )
)

;; Request AI analysis for a problem
(define-public (request-ai-analysis (problem-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get creator problem)) ERR_UNAUTHORIZED)
        (asserts! (not (get ai-analysis-requested problem)) ERR_INVALID_PARAMETERS)
        
        (map-set problems { problem-id: problem-id }
            (merge problem { ai-analysis-requested: true })
        )
        (ok true)
    )
)

;; Submit AI analysis results (called by AI oracle)
(define-public (submit-ai-analysis
    (problem-id uint)
    (complexity-assessment uint)
    (domain-classification uint)
    (solution-approaches (string-ascii 512))
    (success-probability uint)
    (resource-estimation uint)
    (risk-factors (string-ascii 256)))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        ;; In MVP, anyone can submit AI analysis (in production, restrict to AI oracle)
        (asserts! (get ai-analysis-requested problem) ERR_INVALID_PARAMETERS)
        (asserts! (and (<= complexity-assessment u5) (<= domain-classification u7)) ERR_INVALID_PARAMETERS)
        (asserts! (<= success-probability u100) ERR_INVALID_PARAMETERS)
        
        (map-set ai-analysis { problem-id: problem-id }
            {
                complexity-assessment: complexity-assessment,
                domain-classification: domain-classification,
                solution-approaches: solution-approaches,
                success-probability: success-probability,
                resource-estimation: resource-estimation,
                risk-factors: risk-factors,
                analyzed-at: burn-block-height
            }
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-problem (problem-id uint))
    (map-get? problems { problem-id: problem-id })
)

(define-read-only (get-solution (solution-id uint))
    (map-get? solutions { solution-id: solution-id })
)

(define-read-only (get-solver-profile (solver principal))
    (map-get? solver-profiles { solver: solver })
)

(define-read-only (get-platform-tokens (holder principal))
    (map-get? platform-tokens { holder: holder })
)

(define-read-only (get-ai-analysis (problem-id uint))
    (map-get? ai-analysis { problem-id: problem-id })
)

(define-read-only (get-problem-counter)
    (var-get problem-counter)
)

(define-read-only (get-solution-counter)
    (var-get solution-counter)
)

(define-read-only (get-platform-stats)
    {
        total-problems: (var-get problem-counter),
        total-solutions: (var-get solution-counter),
        platform-tokens: (var-get total-platform-tokens),
        platform-fee: (var-get platform-fee-percentage)
    }
)

;; Admin functions (contract owner only)
(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee u20) ERR_INVALID_PARAMETERS) ;; Max 20% fee
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (update-min-reputation (new-min uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set min-solver-reputation new-min)
        (ok true)
    )
)

(define-public (mint-platform-tokens (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (let 
            (
                (current-tokens (default-to { balance: u0 } 
                    (map-get? platform-tokens { holder: recipient })))
            )
            (map-set platform-tokens { holder: recipient }
                { balance: (+ (get balance current-tokens) amount) })
            (var-set total-platform-tokens (+ (var-get total-platform-tokens) amount))
            (ok true)
        )
    )
)