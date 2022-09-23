--
-- PV_ANEMON_LOYALTY  (View)
--
CREATE OR REPLACE VIEW PV_ANEMON_LOYALTY AS
    SELECT resort
         , name_id
         , confirmation_no
         , title
         , LAST
         , FIRST
         , id_number
         , email
         , mobilephone
         , travel_agent
         , company
         , group_name
         , checkin
         , checkout
         , nights
         , adults
         , SUM ( room_revenue) room_revenue
         , SUM ( anemon_puan) anemon_puan
         , SUM ( pck_revenue) pck_revenue
         , SUM ( room_revenue) + SUM ( pck_revenue) room_pck_revenue
         , SUM ( extra_revenue) extra_revenue
         , SUM ( total_revenue) total_revenue
         , REPLACE ( LTRIM ( RTRIM ( XMLAGG (XMLELEMENT ( e, bill_no || ',') ORDER BY bill_no).EXTRACT ( '//text()'), ','), ','), ',,', ',') bill_no
    FROM (SELECT resort
               , name_id
               , confirmation_no
               , title
               , LAST
               , FIRST
               , id_number
               , email
               , mobilephone
               , travel_agent
               , company
               , group_name
               , checkin
               , checkout
               , nights
               , adults
               , SUM ( CASE WHEN IS_ANEMON_PUAN = 'Y' THEN 0 ELSE room_revenue END) room_revenue
               , SUM ( CASE WHEN IS_ANEMON_PUAN = 'Y' THEN room_revenue ELSE 0 END) anemon_puan
               , SUM ( pck_revenue) pck_revenue
               , SUM ( total_revenue) - SUM ( room_revenue) - SUM ( pck_revenue) extra_revenue
               , SUM ( total_revenue) total_revenue
               , bill_no
          --         , RTRIM ( XMLAGG ( XMLELEMENT ( e, bill_no || ',')).EXTRACT ( '//text()'), ',') bill_no
          FROM (SELECT ft.resort
                     , n.name_id
                     , rn.confirmation_no
                     , ft.original_resv_name_id
                     , n.title
                     , n.LAST
                     , n.FIRST
                     , COALESCE ( ppgiykimbil.tc_id_number ( NULL, n.name_id), ppgiykimbil.id_number ( NULL, n.name_id)) id_number
                     , name_ref.get_phone_no ( n.name_id, 'EMAIL') email
                     , COALESCE ( name_ref.get_phone_no ( n.name_id, 'MOBILE', 'PHONE'), name_ref.get_phone_no ( n.name_id, 'PHONE')) mobilephone
                     , (SELECT reservation_ref.get_name ( dn.travel_agent_id)
                        FROM reservation_daily_element_name dn INNER JOIN reservation_daily_elements e ON (e.resort = dn.resort AND e.reservation_date = dn.reservation_date AND e.resv_daily_el_seq = dn.resv_daily_el_seq)
                        WHERE (dn.resort = rn.resort AND dn.resv_name_id = rn.resv_name_id AND dn.reservation_date = rn.trunc_end_date))
                           travel_agent
                     , (SELECT reservation_ref.get_name ( dn.company_id)
                        FROM reservation_daily_element_name dn INNER JOIN reservation_daily_elements e ON (e.resort = dn.resort AND e.reservation_date = dn.reservation_date AND e.resv_daily_el_seq = dn.resv_daily_el_seq)
                        WHERE (dn.resort = rn.resort AND dn.resv_name_id = rn.resv_name_id AND dn.reservation_date = rn.trunc_end_date))
                           company
                     , (SELECT reservation_ref.get_name ( dn.GROUP_ID)
                        FROM reservation_daily_element_name dn INNER JOIN reservation_daily_elements e ON (e.resort = dn.resort AND e.reservation_date = dn.reservation_date AND e.resv_daily_el_seq = dn.resv_daily_el_seq)
                        WHERE (dn.resort = rn.resort AND dn.resv_name_id = rn.resv_name_id AND dn.reservation_date = rn.trunc_end_date))
                           group_name
                     , trunc_begin_date checkin
                     , trunc_end_date checkout
                     , trunc_end_date - trunc_begin_date nights
                     , (SELECT dn.adults
                        FROM reservation_daily_element_name dn INNER JOIN reservation_daily_elements e ON (e.resort = dn.resort AND e.reservation_date = dn.reservation_date AND e.resv_daily_el_seq = dn.resv_daily_el_seq)
                        WHERE (dn.resort = rn.resort AND dn.resv_name_id = rn.resv_name_id AND dn.reservation_date = rn.trunc_end_date))
                           adults
                     , NVL (
                            CASE
                                WHEN tc.trx_code_type = 'L' THEN
                                      ft.gross_amount
                                    + CASE ft.tax_inclusive_yn
                                          WHEN 'N' THEN
                                              ppf.calc_tax (
                                                            ft.trx_no
                                                          , ft.tax_inclusive_yn
                                                          , ft.net_amount
                                                          , ft.gross_amount
                                                           )
                                          ELSE
                                              0
                                      END
                            END
                          , 0
                           )
                           room_revenue
                     , NVL (
                            CASE
                                WHEN (SELECT rp.pkg_forcast_group
                                      FROM resort_products rp
                                      WHERE ft.product = rp.product AND ft.resort = rp.resort)
                                         IS NOT NULL
                                 AND NVL (tc.trx_code_type, '@') NOT IN ('L', 'X') THEN
                                      ft.gross_amount
                                    + CASE ft.tax_inclusive_yn
                                          WHEN 'N' THEN
                                              ppf.calc_tax (
                                                            ft.trx_no
                                                          , ft.tax_inclusive_yn
                                                          , ft.net_amount
                                                          , ft.gross_amount
                                                           )
                                          ELSE
                                              0
                                      END
                            END
                          , 0
                           )
                           pck_revenue
                     -- EXTRAREVENUE
                     ,   ft.gross_amount
                       + CASE ft.tax_inclusive_yn
                             WHEN 'N' THEN
                                 ppf.calc_tax (
                                               ft.trx_no
                                             , ft.tax_inclusive_yn
                                             , ft.net_amount
                                             , ft.gross_amount
                                              )
                             ELSE
                                 0
                         END
                           total_revenue
                     , ft.bill_no
                     , CASE WHEN ft.trx_code = '1035' THEN 'Y' ELSE 'N' END IS_ANEMON_PUAN
                FROM (financial_transactions ft INNER JOIN reservation_name rn ON ft.resort = rn.resort AND ft.original_resv_name_id = rn.resv_name_id)
                     INNER JOIN name n ON rn.name_id = n.name_id
                     INNER JOIN trx$_codes tc ON tc.resort = ft.resort AND tc.trx_code = ft.trx_code
                WHERE ft.ft_subtype = 'C' AND ft.trx_no_added_by IS NULL AND rn.resv_status = 'CHECKED OUT')
          GROUP BY resort
                 , name_id
                 , confirmation_no
                 , title
                 , LAST
                 , FIRST
                 , id_number
                 , email
                 , mobilephone
                 , travel_agent
                 , company
                 , group_name
                 , checkin
                 , checkout
                 , nights
                 , adults
                 , bill_no)
    GROUP BY resort
           , name_id
           , confirmation_no
           , title
           , LAST
           , FIRST
           , id_number
           , email
           , mobilephone
           , travel_agent
           , company
           , group_name
           , checkin
           , checkout
           , nights
           , adults;