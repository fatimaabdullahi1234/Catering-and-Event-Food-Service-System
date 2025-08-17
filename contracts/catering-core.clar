;; Catering Core Contract
;; Manages catering orders, pricing, payments, and basic operations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-ORDER (err u101))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u102))
(define-constant ERR-ORDER-NOT-FOUND (err u103))
(define-constant ERR-ORDER-ALREADY-CONFIRMED (err u104))
(define-constant ERR-ORDER-CANCELLED (err u105))
(define-constant ERR-INVALID-STATUS (err u106))
(define-constant ERR-REFUND-FAILED (err u107))
(define-constant ERR-INVALID-INPUT (err u108))

;; Order status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-CONFIRMED u1)
(define-constant STATUS-IN-PREPARATION u2)
(define-constant STATUS-READY u3)
(define-constant STATUS-DELIVERED u4)
(define-constant STATUS-COMPLETED u5)
(define-constant STATUS-CANCELLED u6)

;; Data Variables
(define-data-var next-order-id uint u1)
(define-data-var base-price-per-guest uint u50000) ;; 0.05 STX per guest
(define-data-var deposit-percentage uint u25) ;; 25% deposit required

;; Data Maps
(define-map orders uint {
  customer: principal,
  total-amount: uint,
  deposit-paid: uint,
  remaining-balance: uint,
  event-description: (string-ascii 500),
  event-timestamp: uint,
  guest-count: uint,
  status: uint,
  created-at: uint,
  dietary-requirements: (string-ascii 200),
  special-instructions: (string-ascii 300)
})

(define-map order-payments uint {
  total-paid: uint,
  deposit-timestamp: uint,
  final-payment-timestamp: uint,
  refund-amount: uint,
  refund-processed: bool
})

(define-map customer-orders principal (list 50 uint))

;; Authorization map for caterers and staff
(define-map authorized-caterers principal bool)

;; Read-only functions

(define-read-only (get-order (order-id uint))
  (map-get? orders order-id)
)

(define-read-only (get-order-payment-info (order-id uint))
  (map-get? order-payments order-id)
)

(define-read-only (get-customer-orders (customer principal))
  (default-to (list) (map-get? customer-orders customer))
)

(define-read-only (calculate-total-price (guest-count uint))
  (let ((base-cost (* guest-count (var-get base-price-per-guest))))
    (if (> guest-count u100)
        ;; Discount for large events (10% off for 100+ guests)
        (/ (* base-cost u90) u100)
        base-cost
    )
  )
)

(define-read-only (calculate-deposit (total-amount uint))
  (/ (* total-amount (var-get deposit-percentage)) u100)
)

(define-read-only (get-next-order-id)
  (var-get next-order-id)
)

(define-read-only (is-authorized-caterer (caterer principal))
  (default-to false (map-get? authorized-caterers caterer))
)

(define-read-only (get-base-price-per-guest)
  (var-get base-price-per-guest)
)

(define-read-only (get-deposit-percentage)
  (var-get deposit-percentage)
)

;; Private functions

(define-private (is-valid-status (status uint))
  (and (>= status STATUS-PENDING) (<= status STATUS-CANCELLED))
)

(define-private (can-cancel-order (order-id uint) (caller principal))
  (match (map-get? orders order-id)
    order-data (let ((customer (get customer order-data))
                     (status (get status order-data)))
                 (and
                   (or (is-eq caller customer)
                       (is-eq caller CONTRACT-OWNER)
                       (is-authorized-caterer caller))
                   (< status STATUS-IN-PREPARATION)))
    false
  )
)

(define-private (update-customer-order-list (customer principal) (order-id uint))
  (let ((current-orders (get-customer-orders customer)))
    (map-set customer-orders customer (unwrap-panic (as-max-len? (append current-orders order-id) u50)))
  )
)

;; Public functions

(define-public (create-order
  (total-amount uint)
  (event-description (string-ascii 500))
  (event-timestamp uint)
  (guest-count uint)
  (dietary-requirements (string-ascii 200))
  (special-instructions (string-ascii 300)))
  (let ((order-id (var-get next-order-id))
        (calculated-price (calculate-total-price guest-count))
        (deposit-amount (calculate-deposit calculated-price)))

    ;; Validate inputs
    (asserts! (> guest-count u0) ERR-INVALID-INPUT)
    (asserts! (> event-timestamp block-height) ERR-INVALID-INPUT)
    (asserts! (>= total-amount calculated-price) ERR-INSUFFICIENT-PAYMENT)

    ;; Create order record
    (map-set orders order-id {
      customer: tx-sender,
      total-amount: total-amount,
      deposit-paid: u0,
      remaining-balance: total-amount,
      event-description: event-description,
      event-timestamp: event-timestamp,
      guest-count: guest-count,
      status: STATUS-PENDING,
      created-at: block-height,
      dietary-requirements: dietary-requirements,
      special-instructions: special-instructions
    })

    ;; Initialize payment record
    (map-set order-payments order-id {
      total-paid: u0,
      deposit-timestamp: u0,
      final-payment-timestamp: u0,
      refund-amount: u0,
      refund-processed: false
    })

    ;; Update customer order list
    (update-customer-order-list tx-sender order-id)

    ;; Increment order ID for next order
    (var-set next-order-id (+ order-id u1))

    (ok order-id)
  )
)

(define-public (pay-deposit (order-id uint))
  (let ((order-data (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
        (payment-data (unwrap! (map-get? order-payments order-id) ERR-ORDER-NOT-FOUND)))

    ;; Validate order belongs to caller and is in pending status
    (asserts! (is-eq tx-sender (get customer order-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status order-data) STATUS-PENDING) ERR-INVALID-STATUS)

    (let ((deposit-amount (calculate-deposit (get total-amount order-data))))

      ;; Transfer deposit to contract
      (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))

      ;; Update order with deposit payment
      (map-set orders order-id (merge order-data {
        deposit-paid: deposit-amount,
        remaining-balance: (- (get total-amount order-data) deposit-amount),
        status: STATUS-CONFIRMED
      }))

      ;; Update payment record
      (map-set order-payments order-id (merge payment-data {
        total-paid: deposit-amount,
        deposit-timestamp: block-height
      }))

      (ok true)
    )
  )
)

(define-public (pay-remaining-balance (order-id uint))
  (let ((order-data (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
        (payment-data (unwrap! (map-get? order-payments order-id) ERR-ORDER-NOT-FOUND)))

    ;; Validate order belongs to caller and is confirmed
    (asserts! (is-eq tx-sender (get customer order-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status order-data) STATUS-CONFIRMED) ERR-INVALID-STATUS)

    (let ((remaining-amount (get remaining-balance order-data)))

      ;; Transfer remaining balance to contract
      (try! (stx-transfer? remaining-amount tx-sender (as-contract tx-sender)))

      ;; Update order
      (map-set orders order-id (merge order-data {
        remaining-balance: u0
      }))

      ;; Update payment record
      (map-set order-payments order-id (merge payment-data {
        total-paid: (get total-amount order-data),
        final-payment-timestamp: block-height
      }))

      (ok true)
    )
  )
)

(define-public (update-order-status (order-id uint) (new-status uint))
  (let ((order-data (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND)))

    ;; Only authorized caterers or contract owner can update status
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-authorized-caterer tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)

    ;; Update order status
    (map-set orders order-id (merge order-data {
      status: new-status
    }))

    (ok true)
  )
)

(define-public (cancel-order (order-id uint))
  (let ((order-data (unwrap! (map-get? orders order-id) ERR-ORDER-NOT-FOUND))
        (payment-data (unwrap! (map-get? order-payments order-id) ERR-ORDER-NOT-FOUND)))

    ;; Check if order can be cancelled
    (asserts! (can-cancel-order order-id tx-sender) ERR-NOT-AUTHORIZED)

    (let ((refund-amount (get total-paid payment-data))
          (customer (get customer order-data)))

      ;; Update order status to cancelled
      (map-set orders order-id (merge order-data {
        status: STATUS-CANCELLED
      }))

      ;; Process refund if payment was made
      (if (> refund-amount u0)
        (begin
          (try! (as-contract (stx-transfer? refund-amount tx-sender customer)))
          (map-set order-payments order-id (merge payment-data {
            refund-amount: refund-amount,
            refund-processed: true
          }))
        )
        true
      )

      (ok true)
    )
  )
)

(define-public (authorize-caterer (caterer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-caterers caterer true)
    (ok true)
  )
)

(define-public (revoke-caterer-authorization (caterer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-caterers caterer)
    (ok true)
  )
)

(define-public (update-base-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-price u0) ERR-INVALID-INPUT)
    (var-set base-price-per-guest new-price)
    (ok true)
  )
)

(define-public (update-deposit-percentage (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (> new-percentage u0) (<= new-percentage u100)) ERR-INVALID-INPUT)
    (var-set deposit-percentage new-percentage)
    (ok true)
  )
)

;; Emergency functions (contract owner only)

(define-public (emergency-withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    (ok true)
  )
)

(define-public (get-contract-balance)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (stx-get-balance (as-contract tx-sender)))
  )
)
