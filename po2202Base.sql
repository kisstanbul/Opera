-- BEGIN PMS_P.INITIALIZE('NA_REPORTS','NA_REPORTS','BJVRC'); END;
-- select pms_p.business_date from dual;
-- SELECT * FROM resort
WITH giykimbil AS
         (SELECT rn.resort
               , rn.resv_name_id
               , e.reservation_date
               , e.room
               , NVL (n.LAST, n.company) || ',' || NVL (n.FIRST, '') full_name
               , NVL (
                      (SELECT 'Y'
                       FROM reservation_daily_element_name a, reservation_daily_element_name b, reservation_name c
                       WHERE a.resort = rn.resort
                         AND a.resv_name_id = rn.resv_name_id
                         AND b.resort = a.resort
                         AND b.reservation_date = a.reservation_date
                         AND b.resv_daily_el_seq = a.resv_daily_el_seq
                         AND b.resv_name_id != a.resv_name_id
                         AND b.resort = c.resort
                         AND b.resv_name_id = c.resv_name_id
                         AND c.resv_status IN ('RESERVED'
                                             , 'PROSPECT'
                                             , 'CHECKED IN'
                                             , 'CHECKED OUT' -- ?
                                             , 'WAITLIST')
                         AND ROWNUM < 2)
                    , 'N'
                     )
                     shared_yn
               , NVL (
                      (SELECT 'Y'
                       FROM reservation_name
                       WHERE resort = rn.resort AND parent_resv_name_id = rn.resv_name_id AND name_usage_type = 'AG' AND ROWNUM < 2)
                    , 'N'
                     )
                     accompanying_yn
          FROM ((reservation_name rn 
          INNER JOIN reservation_daily_element_name dn ON (dn.resort = rn.resort AND dn.resv_name_id = rn.resv_name_id)) 
          INNER JOIN reservation_daily_elements e ON (e.resort = dn.resort AND e.reservation_date = dn.reservation_date AND e.resv_daily_el_seq = dn.resv_daily_el_seq)) 
          INNER JOIN name n ON (n.name_id = rn.name_id)
          WHERE e.resort = :p_resort AND e.reservation_date >= :p_from_date AND e.reservation_date <= :p_to_date AND rn.resv_status IN ('CHECKED IN', 'CHECKED OUT'))
   , detail AS
         (SELECT COALESCE ( ft.original_resv_name_id, ft.resv_name_id) org_resv_id
               , ft.trx_date
               , ft.name_id
               , NVL (CASE WHEN tc.trx_code_type = 'L' THEN ft.net_amount END, 0) net_room_revenue
               , NVL (CASE WHEN ft.trx_no_against_package IS NOT NULL AND tc.trx_code_type <> 'L' THEN ft.net_amount END, 0) net_pck_revenue
               , CASE
                     WHEN NVL (ft.tax_inclusive_yn, 'N') = 'N' THEN
                         (SELECT SUM ( NVL (ft2.net_amount, 0))
                          FROM financial_transactions ft2
                          WHERE ft2.trx_no_added_by = ft.trx_no
                            AND EXISTS
                                    (SELECT 1
                                     FROM trx$_codes tc
                                     WHERE tc.resort = ft2.resort AND tc.trx_code = ft2.trx_code AND tc.trx_code_type = 'X'))
                     ELSE
                         ft.gross_amount - ft.net_amount
                 END
                     tax
          FROM financial_transactions ft INNER JOIN trx$_codes tc ON ft.resort = tc.resort AND ft.trx_code = tc.trx_code AND tc.trx_code_type <> 'X'
          WHERE ft.resort = :p_resort AND ft.trx_date BETWEEN :p_from_date AND :p_to_date AND ft.ft_subtype = 'C' AND ft.display_yn <> 'N' AND NVL (ft.invoice_type, '@') <> 'CR')
   , qry AS
         (SELECT org_resv_id
               , trx_date
               , SUM ( net_room_revenue + CASE WHEN net_room_revenue <> 0 THEN tax ELSE 0 END) room_revenue
               , SUM ( net_room_revenue) net_room_revenue
               , SUM ( net_pck_revenue + CASE WHEN net_pck_revenue <> 0 THEN tax ELSE 0 END) pck_revenue
               , SUM ( net_pck_revenue) net_pck_revenue
          FROM detail
          GROUP BY org_resv_id, trx_date)
SELECT gkb.resort
     , gkb.reservation_date
     , gkb.full_name
     , gkb.room
     , gkb.shared_yn
     , qry.room_revenue
     , qry.net_room_revenue
     , qry.pck_revenue
     , qry.net_pck_revenue
     , (qry.room_revenue + qry.pck_revenue) total_revenue
     , (qry.net_room_revenue + qry.net_pck_revenue) net_total_revenue
     , (SELECT RTRIM ( XMLAGG ( XMLELEMENT ( e, NVL (n2.LAST, n2.company) || ',' || NVL (n2.FIRST, '') || ',')).EXTRACT ( '//text()'), ',')
        FROM reservation_name rn2 INNER JOIN name n2 ON rn2.name_id = n2.name_id
        WHERE rn2.resort = gkb.resort AND rn2.parent_resv_name_id = gkb.resv_name_id AND rn2.name_usage_type = 'AG')
           accompanying_names
     , gkb.accompanying_yn
FROM giykimbil gkb LEFT OUTER JOIN qry ON gkb.resv_name_id = qry.org_resv_id AND gkb.reservation_date = qry.trx_date