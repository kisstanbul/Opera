--
-- PV_MARRIOTT_RESV_DTL  (View)
--
CREATE OR REPLACE VIEW PV_MARRIOTT_RESV_DTL AS
SELECT rn.resort    
     , (SELECT r.name
        FROM resort r
        WHERE r.resort = rn.resort)
           resort_name
     , rn.resv_name_id
     , rn.confirmation_no
     , (CASE WHEN SUBSTR ( e.room_category, 1, 1) <> '-' THEN CASE WHEN rn.trunc_begin_date = rn.trunc_end_date OR dn.reservation_date < rn.trunc_end_date THEN 1 ELSE 0 END ELSE 0 END) resv_multiplier
     , dn.reservation_date
     , rn.insert_date --  Salesdate
     , rn.business_date_created -- RecordDate --9
     , rn.resv_status
     , rn.trunc_begin_date arrival_date
     , rn.trunc_end_date departure_date
     , e.quantity no_rooms
     , rn.name_id
     , (SELECT n.FIRST
        FROM name n
        WHERE n.name_id = rn.name_id)
           first_name
     , (SELECT n.LAST
        FROM name n
        WHERE n.name_id = rn.name_id)
           last_name
     , dn.adults
     , dn.children
     , dn.children1
     , dn.children2
     , dn.children3
     , dn.children4
     , dn.children5
     , NVL (dn.adults, 0) + NVL (dn.children, 0) Pax
     , NVL (dn.children1, 0) + NVL (dn.children2, 0) + NVL (dn.children3, 0) PaidChild
     , NVL (dn.children4, 0) FreeChild
     , NVL (dn.children5, 0) Baby
     , reservation_ref.get_room_category_label ( e.booked_room_category, e.resort) BookedRoomType
     , reservation_ref.get_room_category_label ( e.room_category, e.resort) RoomType
     , dn.travel_agent_id
     , (SELECT NVL (n.LAST, n.company)
        FROM name n
        WHERE n.name_id = dn.travel_agent_id)
           travel_agent
     , dn.company_id
     , (SELECT NVL (n.LAST, n.company)
        FROM name n
        WHERE n.name_id = dn.company_id)
           company
     , CASE WHEN SUBSTR ( e.room_category, 1, 1) <> '-' THEN 'N' ELSE 'Y' END pm
     , rh.complimentary_yn
     , rh.house_use_yn
     , rn.channel origin_code
     , e.origin_of_booking source_code
     , CASE WHEN e.ALLOTMENT_HEADER_ID IS NULL THEN 'INDIVIDUALS' ELSE 'BLOCKS' END reservation_type
     , (SELECT n.nationality
        FROM name n
        WHERE rn.name_id = n.name_id)
           nationality
     , e.market_code
     , (SELECT m.description
        FROM resort$_markets M
        WHERE m.resort = e.resort AND m.market_code = e.market_code)
           market_code_description
     , CASE WHEN e.allotment_header_id IS NULL THEN 'N' ELSE 'Y' END group_yn
     , (SELECT ah.description
        FROM allotment$header ah
        WHERE ah.resort = e.resort AND ah.allotment_header_id = e.allotment_header_id)
           group_name
     , dn.GROUP_ID
     , (SELECT NVL (n.LAST, n.company)
        FROM name n
        WHERE n.name_id = dn.GROUP_ID)
           group_profile
     , CASE
           WHEN (SELECT COUNT ( dn2.resv_daily_el_seq)
                 FROM reservation_name rn2 INNER JOIN reservation_daily_element_name dn2 ON (dn2.resort = rn2.resort AND dn2.resv_name_id = rn2.resv_name_id)
                 WHERE dn2.resv_daily_el_seq = dn.resv_daily_el_seq AND dn2.reservation_date < rn2.trunc_end_date) <> 1 THEN
               NVL (dn.share_priority, 0)
           ELSE
               1
       END
           share_priority
     , rn.cancellation_date
     , rn.cancellation_reason_code
     -- -------------------------------------------------------------------------- --
     --
     -- -------------------------------------------------------------------------- --
     , dn.currency_code
     , CASE
           WHEN dn.currency_code = (SELECT r.currency_code
                                    FROM resort r
                                    WHERE r.resort = rn.resort) THEN
               1
           ELSE
               (SELECT MIN ( cur.exchange_rate) KEEP (DENSE_RANK FIRST ORDER BY cur.begin_date DESC, NVL (cur.exchange_rate, 0) DESC)
                FROM currency_exchange_rates cur
                WHERE cur.resort = rn.resort
                  AND cur.begin_date >=   LEAST (
                                                 dn.reservation_date
                                               , (SELECT business_date
                                                  FROM businessdate
                                                  WHERE state = 'OPEN' AND resort = rn.resort)
                                                )
                                        - 300
                  AND cur.begin_date <= dn.reservation_date
                  AND cur.base_curr_code = (SELECT r.currency_code
                                            FROM resort r
                                            WHERE r.resort = rn.resort)
                  AND cur.currency_code = dn.currency_code
                  AND cur.exchange_rate_type IN ('ROOM', 'POSTEX1'))
       END
           exchange_rate
     , (SELECT MIN ( cur.exchange_rate) KEEP (DENSE_RANK FIRST ORDER BY cur.begin_date DESC, NVL (cur.exchange_rate, 0) DESC)
        FROM currency_exchange_rates cur
        WHERE cur.resort = rn.resort
          AND cur.begin_date >=   LEAST (
                                         dn.reservation_date
                                       , (SELECT business_date
                                          FROM businessdate
                                          WHERE state = 'OPEN' AND resort = rn.resort)
                                        )
                                - 300
          AND cur.begin_date <= dn.reservation_date
          AND cur.base_curr_code = (SELECT r.currency_code
                                    FROM resort r
                                    WHERE r.resort = rn.resort)
          AND cur.currency_code = 'EUR'
          AND cur.exchange_rate_type IN ('ROOM', 'POSTEX1'))
           eur_exchange_rate
     , CASE
           WHEN dn.reservation_date < (SELECT business_date
                                       FROM businessdate
                                       WHERE state = 'OPEN' AND resort = rn.resort) THEN
               (SELECT rs.room_revenue
                FROM reservation_stat_daily rs
                WHERE rs.resort = dn.resort AND rs.resv_name_id = dn.resv_name_id AND rs.business_date = dn.reservation_date)
           ELSE
               (SELECT rs.net_room_revenue
                FROM reservation_summary rs
                WHERE rs.resort = dn.resort AND TO_NUMBER ( rs.event_id) = dn.resv_name_id AND rs.considered_date = dn.reservation_date)
       END
           room_revenue
     , CASE
           WHEN dn.reservation_date < (SELECT business_date
                                       FROM businessdate
                                       WHERE state = 'OPEN' AND resort = rn.resort) THEN
               (SELECT rs.total_room_tax
                FROM reservation_stat_daily rs
                WHERE rs.resort = dn.resort AND rs.resv_name_id = dn.resv_name_id AND rs.business_date = dn.reservation_date)
           ELSE
               (SELECT rs.room_revenue_tax
                FROM reservation_summary rs
                WHERE rs.resort = dn.resort AND TO_NUMBER ( rs.event_id) = dn.resv_name_id AND rs.considered_date = dn.reservation_date)
       END
           room_revenue_tax
     -- -------------------------------------------------------------------------- --
     --
     -- -------------------------------------------------------------------------- --
     , (SELECT na.country
        FROM name_address na
        WHERE na.address_id = rn.address_id)
           guest_country
     , CASE
           WHEN EXISTS
                    (SELECT 1
                     FROM reservation_name rnhist
                     WHERE rnhist.name_id = rn.name_id AND rnhist.trunc_begin_date < rn.trunc_begin_date AND rnhist.resv_status = 'CHECKED OUT') THEN
               'Y'
           ELSE
               'N'
       END
           repeat_yn
     , rn.payment_method
     --
     , CASE WHEN rn.resv_status = 'CANCELLED' THEN 'Cancel' ELSE 'Actual' END Rez_Durumu
     , CASE WHEN rn.resv_status = 'CANCELLED' THEN 'Cancel' ELSE 'Record' END Type_
     , CASE WHEN dn.reservation_date = rn.trunc_begin_date THEN 1 ELSE 0 END AS GirisGunu
     , (SELECT p.acc_code
        FROM ar$_account ar JOIN proteldb.ppor_ar p ON p.resort = ar.resort AND ar.account_code = p.account_code
        WHERE ar.resort = p.resort AND ar.name_id = dn.travel_agent_id AND p.acc_code IS NOT NULL AND ROWNUM = 1)
           acc_code
     , (SELECT p.acc_code
        FROM proteldb.ppor_name_ar p
        WHERE p.name_id = dn.travel_agent_id)
           acc_code2
FROM reservation_name rn
     INNER JOIN reservation_daily_element_name dn ON (dn.resort = rn.resort AND dn.resv_name_id = rn.resv_name_id)
     INNER JOIN reservation_daily_elements e ON (e.resort = dn.resort AND e.reservation_date = dn.reservation_date AND e.resv_daily_el_seq = dn.resv_daily_el_seq)
     LEFT JOIN rate_header rh ON rh.resort = dn.resort AND rh.rate_code = dn.rate_code
WHERE (rn.event_id IS NULL
    OR (rn.event_id IS NOT NULL AND e.room_category NOT LIKE '-%')
    OR (rn.event_id IS NOT NULL AND e.room_category LIKE '-%')
   -- AND dn.reservation_date > (SELECT business_date FROM businessdate WHERE state = 'OPEN' AND resort = rn.resort)
   -- AND dn.reservation_date = (SELECT business_date FROM businessdate WHERE state = 'OPEN' AND resort = rn.resort)
   -- AND rn.trunc_begin_date > (SELECT business_date FROM businessdate WHERE state = 'OPEN' AND resort = rn.resort)
   );
