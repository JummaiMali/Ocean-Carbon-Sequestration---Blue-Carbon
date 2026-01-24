(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROJECT_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_CREDITS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_PROJECT_NOT_VERIFIED (err u104))
(define-constant ERR_ORACLE_NOT_AUTHORIZED (err u105))
(define-constant ERR_INVALID_PROJECT_TYPE (err u106))
(define-constant ERR_PROJECT_ALREADY_EXISTS (err u107))
(define-constant REWARD_RATE u1000)

(define-fungible-token blue-carbon-credits)

(define-map projects
  { project-id: uint }
  {
    owner: principal,
    project-type: (string-ascii 20),
    location: (string-ascii 100),
    area-hectares: uint,
    credits-minted: uint,
    verified: bool,
    verification-date: uint,
    oracle: (optional principal)
  }
)

(define-map project-credits
  { project-id: uint }
  { total-credits: uint, available-credits: uint }
)

(define-map marketplace-orders
  { order-id: uint }
  {
    seller: principal,
    project-id: uint,
    credits-amount: uint,
    price-per-credit: uint,
    active: bool
  }
)

(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool }
)
(define-map retired-credits
  { account: principal }
  { total-retired: uint }
)

(define-map staked-credits
  { account: principal }
  { amount: uint, stake-time: uint }
)

(define-map project-funds
  { project-id: uint }
  { total-funds: uint }
)

(define-data-var next-project-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var contract-paused bool false)

(define-public (register-project 
  (project-type (string-ascii 20))
  (location (string-ascii 100))
  (area-hectares uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (> area-hectares u0) ERR_INVALID_AMOUNT)
    (asserts! (or 
      (is-eq project-type "mangrove")
      (is-eq project-type "seagrass")
      (is-eq project-type "kelp-forest")) ERR_INVALID_PROJECT_TYPE)
    
    (let ((project-id (var-get next-project-id)))
      (map-set projects
        { project-id: project-id }
        {
          owner: tx-sender,
          project-type: project-type,
          location: location,
          area-hectares: area-hectares,
          credits-minted: u0,
          verified: false,
          verification-date: u0,
          oracle: none
        }
      )
      (map-set project-credits
        { project-id: project-id }
        { total-credits: u0, available-credits: u0 }
      )
      (var-set next-project-id (+ project-id u1))
      (ok project-id)
    )
  )
)

(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: true })
    (ok true)
  )
)

(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-oracles { oracle: oracle } { authorized: false })
    (ok true)
  )
)

(define-public (verify-project 
  (project-id uint)
  (carbon-credits uint))
  (let ((project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
        (oracle-auth (default-to { authorized: false } (map-get? authorized-oracles { oracle: tx-sender }))))
    
    (asserts! (get authorized oracle-auth) ERR_ORACLE_NOT_AUTHORIZED)
    (asserts! (> carbon-credits u0) ERR_INVALID_AMOUNT)
    
    (map-set projects
      { project-id: project-id }
      (merge project {
        verified: true,
        verification-date: burn-block-height,
        oracle: (some tx-sender),
        credits-minted: carbon-credits
      })
    )
    (map-set project-credits
      { project-id: project-id }
      { total-credits: carbon-credits, available-credits: carbon-credits }
    )
    (try! (ft-mint? blue-carbon-credits carbon-credits (get owner project)))
    (ok true)
  )
)

(define-public (create-sell-order 
  (project-id uint)
  (credits-amount uint)
  (price-per-credit uint))
  (let ((project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
        (credits-data (unwrap! (map-get? project-credits { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
        (order-id (var-get next-order-id)))
    
    (asserts! (get verified project) ERR_PROJECT_NOT_VERIFIED)
    (asserts! (is-eq tx-sender (get owner project)) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get available-credits credits-data) credits-amount) ERR_INSUFFICIENT_CREDITS)
    (asserts! (> credits-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-credit u0) ERR_INVALID_AMOUNT)
    
    (map-set marketplace-orders
      { order-id: order-id }
      {
        seller: tx-sender,
        project-id: project-id,
        credits-amount: credits-amount,
        price-per-credit: price-per-credit,
        active: true
      }
    )
    (map-set project-credits
      { project-id: project-id }
      (merge credits-data { available-credits: (- (get available-credits credits-data) credits-amount) })
    )
    (var-set next-order-id (+ order-id u1))
    (ok order-id)
  )
)

(define-public (buy-credits (order-id uint))
  (let ((order (unwrap! (map-get? marketplace-orders { order-id: order-id }) ERR_PROJECT_NOT_FOUND))
        (total-cost (* (get credits-amount order) (get price-per-credit order))))
    
    (asserts! (get active order) ERR_PROJECT_NOT_FOUND)
    (asserts! (not (is-eq tx-sender (get seller order))) ERR_NOT_AUTHORIZED)
    
    (try! (stx-transfer? total-cost tx-sender (get seller order)))
    (try! (ft-transfer? blue-carbon-credits (get credits-amount order) (get seller order) tx-sender))
    
    (map-set marketplace-orders
      { order-id: order-id }
      (merge order { active: false })
    )
    (ok true)
  )
)

(define-public (cancel-sell-order (order-id uint))
  (let ((order (unwrap! (map-get? marketplace-orders { order-id: order-id }) ERR_PROJECT_NOT_FOUND))
        (credits-data (unwrap! (map-get? project-credits { project-id: (get project-id order) }) ERR_PROJECT_NOT_FOUND)))
    
    (asserts! (is-eq tx-sender (get seller order)) ERR_NOT_AUTHORIZED)
    (asserts! (get active order) ERR_PROJECT_NOT_FOUND)
    
    (map-set marketplace-orders
      { order-id: order-id }
      (merge order { active: false })
    )
    (map-set project-credits
      { project-id: (get project-id order) }
      (merge credits-data { available-credits: (+ (get available-credits credits-data) (get credits-amount order)) })
    )
    (ok true)
  )
)

(define-public (transfer-credits (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (ft-transfer? blue-carbon-credits amount tx-sender recipient)
  )
)

(define-public (batch-transfer-credits (recipients (list 10 { recipient: principal, amount: uint })))
  (let ((total-amount (fold add-amount recipients u0)))
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance blue-carbon-credits tx-sender) total-amount) ERR_INSUFFICIENT_CREDITS)
    (fold transfer-single recipients (ok true))
  )
)

(define-private (transfer-single (transfer-data { recipient: principal, amount: uint }) (result (response bool uint)))
  (match result
    success (ft-transfer? blue-carbon-credits (get amount transfer-data) tx-sender (get recipient transfer-data))
    error (err error)
  )
)

(define-private (add-amount (data { recipient: principal, amount: uint }) (acc uint))
  (+ acc (get amount data))
)
(define-public (retire-credits (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (ft-burn? blue-carbon-credits amount tx-sender))
    (let ((current-retired (default-to { total-retired: u0 } (map-get? retired-credits { account: tx-sender }))))
      (map-set retired-credits
        { account: tx-sender }
        { total-retired: (+ (get total-retired current-retired) amount) }
      )
    )
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (stake-credits (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance blue-carbon-credits tx-sender) amount) ERR_INSUFFICIENT_CREDITS)
    (let ((existing-stake (default-to { amount: u0, stake-time: u0 } (map-get? staked-credits { account: tx-sender }))))
      (try! (ft-transfer? blue-carbon-credits amount tx-sender (as-contract tx-sender)))
      (map-set staked-credits
        { account: tx-sender }
        { amount: (+ (get amount existing-stake) amount), stake-time: burn-block-height }
      )
      (ok true)
    )
  )
)

(define-public (unstake-credits (amount uint))
  (let ((stake-data (unwrap! (map-get? staked-credits { account: tx-sender }) ERR_INSUFFICIENT_CREDITS))
        (current-time burn-block-height)
        (staked-amount (get amount stake-data))
        (stake-time (get stake-time stake-data))
        (rewards (/ (* staked-amount (- current-time stake-time)) REWARD_RATE)))
    (asserts! (>= staked-amount amount) ERR_INSUFFICIENT_CREDITS)
    (try! (ft-transfer? blue-carbon-credits amount (as-contract tx-sender) tx-sender))
    (try! (ft-mint? blue-carbon-credits rewards tx-sender))
    (if (is-eq (- staked-amount amount) u0)
      (map-delete staked-credits { account: tx-sender })
      (map-set staked-credits
        { account: tx-sender }
        { amount: (- staked-amount amount), stake-time: stake-time }
      )
    )
    (ok rewards)
  )
)

(define-public (claim-rewards)
  (let ((stake-data (unwrap! (map-get? staked-credits { account: tx-sender }) ERR_INSUFFICIENT_CREDITS))
        (current-time burn-block-height)
        (staked-amount (get amount stake-data))
        (stake-time (get stake-time stake-data))
        (rewards (/ (* staked-amount (- current-time stake-time)) REWARD_RATE)))
    (try! (ft-mint? blue-carbon-credits rewards tx-sender))
    (map-set staked-credits
      { account: tx-sender }
      { amount: staked-amount, stake-time: current-time }
    )
    (ok rewards)
  )
)

(define-public (donate-to-project (project-id uint) (amount uint))
  (let ((project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((current-funds (default-to { total-funds: u0 } (map-get? project-funds { project-id: project-id }))))
      (map-set project-funds
        { project-id: project-id }
        { total-funds: (+ (get total-funds current-funds) amount) }
      )
    )
    (ok true)
  )
)

(define-public (withdraw-project-funds (project-id uint) (amount uint))
  (let ((project (unwrap! (map-get? projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
        (funds-data (unwrap! (map-get? project-funds { project-id: project-id }) ERR_INSUFFICIENT_CREDITS)))
    (asserts! (is-eq tx-sender (get owner project)) ERR_NOT_AUTHORIZED)
    (asserts! (>= (get total-funds funds-data) amount) ERR_INSUFFICIENT_CREDITS)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (as-contract (stx-transfer? amount tx-sender (get owner project))))
    (map-set project-funds
      { project-id: project-id }
      { total-funds: (- (get total-funds funds-data) amount) }
    )
    (ok true)
  )
)

(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-project-credits (project-id uint))
  (map-get? project-credits { project-id: project-id })
)

(define-read-only (get-sell-order (order-id uint))
  (map-get? marketplace-orders { order-id: order-id })
)

(define-read-only (get-balance (account principal))
  (ft-get-balance blue-carbon-credits account)
)

(define-read-only (get-total-supply)
  (ft-get-supply blue-carbon-credits)
)

(define-read-only (is-oracle-authorized (oracle principal))
  (default-to { authorized: false } (map-get? authorized-oracles { oracle: oracle }))
)

(define-read-only (get-contract-info)
  {
    next-project-id: (var-get next-project-id),
    next-order-id: (var-get next-order-id),
    contract-paused: (var-get contract-paused),
    total-supply: (ft-get-supply blue-carbon-credits)
  }
)

(define-read-only (get-retired-credits (account principal))
  (default-to { total-retired: u0 } (map-get? retired-credits { account: account }))
)

(define-read-only (get-staked-credits (account principal))
  (default-to { amount: u0, stake-time: u0 } (map-get? staked-credits { account: account }))
)

(define-read-only (get-project-funds (project-id uint))
  (default-to { total-funds: u0 } (map-get? project-funds { project-id: project-id }))
)
