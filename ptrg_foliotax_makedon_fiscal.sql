CREATE OR REPLACE TRIGGER ptrg_foliotax_makedon_fiscal
    BEFORE INSERT
    ON folio$_tax
    FOR EACH ROW
DECLARE
    l_url VARCHAR2 (4000);
    -- :='http://192.168.8.203:7479/api/fiscal/ProcessDoc/';
    -- l_items VARCHAR2 (4000);
    -- l_payments VARCHAR2 (4000);
    content VARCHAR2 (4000);
    l_pposting_count NUMBER;
    l_mpayment_count NUMBER;
    l_error_count NUMBER;
    l_status_code NUMBER;
    FUNCTION send_invoice ( in_url IN VARCHAR2, in_content IN VARCHAR2)
        RETURN NUMBER IS
        l_http_request UTL_HTTP.req;
        l_http_response UTL_HTTP.resp;
        l_return NUMBER;
    -- buffer VARCHAR2 (4000);
    BEGIN
        pplog.LOG ( 'Begin Fiscal Bill', :NEW.BILL_NO);

        l_http_request := UTL_HTTP.begin_request ( in_url, 'POST', ' HTTP/1.1');
        UTL_HTTP.set_header ( l_http_request, 'user-agent', 'mozilla/4.0');
        UTL_HTTP.set_header ( l_http_request, 'content-type', 'application/json');
        UTL_HTTP.SET_HEADER ( r => l_http_request, NAME => 'Content-Length', VALUE => LENGTHB ( in_content));
        UTL_HTTP.WRITE_RAW ( r => l_http_request, DATA => UTL_RAW.CAST_TO_RAW ( in_content));
        l_http_response := UTL_HTTP.get_response ( l_http_request);

        pplog.LOG ( 'POST Api Response Status Code', l_http_response.status_code);

        pplog.LOG ( 'End Fiscal Bill', :NEW.BILL_NO || ' , Status Code: ' || l_http_response.status_code);
        /*
        -- -------------------------------------------------------------------------- --
        -- Read resonse
        -- -------------------------------------------------------------------------- --
        --20222107 BEGIN
        LOOP -- pt_log
            UTL_HTTP.read_line ( l_http_response, buffer);
            IF INSTR ( buffer, '"ResponseMessage"') > 0 THEN
                pplog.LOG ( 'POST Api Response', buffer);
                --{"HttpStatusCode":500,"ResponseMessage":"Fiscal Device is not Ready"}
                IF buffer NOT LIKE '%"HttpStatusCode":200%"ResponseMessage":"OK"%' THEN
                    pplog.err ( 'POST Api Err.Response' || buffer);
                    l_error_count := NVL (l_error_count, 0) + 1;
                    RAISE_APPLICATION_ERROR ( -20007, 'POST Api Err.Response' || buffer);
                END IF;
            END IF;
        END LOOP;
        IF l_error_count <> 0 THEN
            RAISE_APPLICATION_ERROR ( -20001, 'l_error_count<>0');
        END IF;
        */

        --IF l_http_response.status_code <> 200 THEN     --RAISE_APPLICATION_ERROR ( -20001, 'RuleErr(8):Status code <> 200');     --  END IF;
        l_return := l_http_response.status_code;
        UTL_HTTP.end_response ( l_http_response);
        RETURN (l_return);
    EXCEPTION
        WHEN OTHERS THEN
            UTL_HTTP.end_response ( l_http_response);
            RETURN (0); --  Fail<> 200
    END send_invoice;
    FUNCTION lf_url
        RETURN VARCHAR2 IS
        l_return VARCHAR2 (4000);
    BEGIN
        -- -------------------------------------------------------------------------- --
        -- API : Get API address
        -- -------------------------------------------------------------------------- --
        SELECT TRIM ( description)
        INTO l_return
        FROM pms_terminals
        WHERE station_id = :new.terminal;

        -- http://DESKTOP-MBV5CM3:7479/api/Fiscal/ProcessDoc/
        pplog.LOG ( 'POST Api URL', l_return);
        -- -------------------------------------------------------------------------- --
        RETURN (l_return);
    END lf_url;

    FUNCTION lf_content
        RETURN VARCHAR2 IS
        l_items VARCHAR2 (4000);
        l_payments VARCHAR2 (4000);
    BEGIN
        SELECT '"Items":[' || UTL_I18N.unescape_reference ( RTRIM ( XMLAGG ( XMLELEMENT ( e, item || ',')).EXTRACT ( '//text()'), ',')) || ']'
        INTO l_items
        FROM (SELECT REPLACE ( TRIM ( '{"TrxCode":"' || trx_code || '","ItemName": "' || description || '","VatRate": ' || TO_CHAR ( tax_percentage, '990') || ',"Price": ' || TO_CHAR ( ABS ( SUM ( gross_amount)), '999999990D00') || ',"Quantity":1' || '}'), ' ', '') item
              FROM (SELECT NVL (
                                (SELECT tr.arrangement_code
                                 FROM trx$_code_arrangement tr
                                 WHERE tr.resort = ft.resort AND tr.arrangement_id = ft.arrangement_id)
                              , ft.trx_code
                               )
                               trx_code
                         , NVL (
                                (SELECT ftt.description
                                 FROM fin_trx_translation ftt
                                 WHERE ftt.resort = ft.resort AND ftt.arrangement_id = ft.arrangement_id AND ftt.translated_column = 'Arrangement_desc' AND ftt.language_code = 'MK')
                              , tc.description
                               )
                               description
                         , ppf.calc_tax_percentage (
                                                    ft.trx_no
                                                  , ft.tax_inclusive_yn
                                                  , ft.net_amount
                                                  , ft.gross_amount
                                                  , -1
                                                   )
                               tax_percentage
                         , ft.gross_amount
                    FROM financial_transactions ft INNER JOIN trx$_codes tc ON tc.resort = ft.resort AND tc.trx_code = ft.trx_code
                    WHERE ft.resort = :new.resort AND ft.resv_name_id = :new.resv_name_id AND ft.folio_view = :new.folio_view AND ft.gross_amount <> 0 AND NVL (tc.trx_code_type, '@') <> 'X' AND NVL (ft.bill_no, :NEW.BILL_NO) = :NEW.BILL_NO)
              GROUP BY trx_code, description, tax_percentage
              HAVING SUM ( gross_amount) <> 0);

        SELECT '"Payments":[' || UTL_I18N.unescape_reference ( RTRIM ( XMLAGG ( XMLELEMENT ( e, item || ',')).EXTRACT ( '//text()'), ',')) || ']'
        INTO l_payments
        FROM (SELECT REPLACE ( TRIM ( '{"TrxCode":' || trx_code || ',"Name": "' || description || '","PaymentType":0 ' || ',"OptionPaymentType": ' || cc_type || ',"Total": ' || TO_CHAR ( ABS ( SUM ( payment)), '999999990D00') || '}'), ' ', '') item
              FROM (SELECT ft.trx_code
                         , CASE WHEN tc.cc_type IS NOT NULL THEN '1' ELSE '0' END cc_type
                         , NVL (
                                (SELECT ftt.description
                                 FROM fin_trx_translation ftt
                                 WHERE ftt.resort = ft.resort AND ftt.trx_code = ft.trx_code AND ftt.translated_column = 'DESCRIPTION' AND ftt.language_code = 'MK')
                              , tc.description
                               )
                               description
                         , NVL (ft.guest_account_credit, 0) - NVL (ft.guest_account_debit, 0) payment
                    FROM financial_transactions ft INNER JOIN trx$_codes tc ON tc.resort = ft.resort AND tc.trx_code = ft.trx_code
                    WHERE ft.resort = :new.resort AND ft.resv_name_id = :new.resv_name_id AND ft.folio_view = :new.folio_view AND ft.trx_no_added_by IS NULL AND (ft.ft_subtype = 'FC' OR ppf.get_param ( ft.resort, 'DEPOSIT_LED_TRX_CODE') = ft.trx_code) AND NVL (ft.bill_no, :NEW.BILL_NO) = :NEW.BILL_NO)
              GROUP BY trx_code, description, cc_type
              HAVING SUM ( payment) <> 0);

        RETURN ('{"FiscalDocType": ' || CASE WHEN :NEW.TOTAL_GROSS > 0 THEN '1' ELSE '0' END || ',"TransactionID" : "' || :NEW.RESORT || '-' || TO_CHAR ( :NEW.BILL_NO) || '",' || l_items || ',' || l_payments || '}');
    END lf_content;
BEGIN
    -- -------------------------------------------------------------------------- --
    -- 20221208 kcelik@protel.com.tr
    -- -------------------------------------------------------------------------- --
    -- New rules...
    -- -------------------------------------------------------------------------- --
    -- 20210407 kcelik@protel.com.tr
    -- -------------------------------------------------------------------------- --
    -- Rule1: Group1 (CL,D,Oth)
    --        If Total Payment = (CL+D+Oth) Trigger will not work
    --        Exp: %30 CL + %70 D = %100 Payment
    -- Rule2: Group2 (CC,Cash)
    --        If Total Payment = (CC+Cash) Trigger will work
    --        CASHPAY -- CCPAY
    -- Rule3: Group1 and Group2  cannot be used at the same time
    -- Rule4: If the Invoice total is negative, it is the return invoice . The return invoice does not have positive posting.
    -- Rule5: The total amount must be an integer. Users must rebate decimal numbers.
    -- Rule6: Micros Payment (mpayment) cannot user for fiscal invoice
    --
    l_error_count := 0;

    IF NVL (:NEW.TOTAL_GROSS, 0) <> 0 THEN
        SELECT COUNT ( *)
        INTO l_mpayment_count
        FROM financial_transactions ft INNER JOIN trx$_codes tc ON tc.resort = ft.resort AND tc.trx_code = ft.trx_code
        WHERE ft.resort = :new.resort AND ft.resv_name_id = :new.resv_name_id AND ft.folio_view = :new.folio_view AND ft.trx_no_added_by IS NULL AND (ft.ft_subtype = 'FC' AND ppf.get_param ( ft.resort, 'DEPOSIT_LED_TRX_CODE') <> ft.trx_code) AND NVL (ft.bill_no, :NEW.BILL_NO) = :NEW.BILL_NO AND tc.ind_billing = 'N';

        -- -------------------------------------------------------------------------- --
        --  Rule6
        -- -------------------------------------------------------------------------- --
        IF l_mpayment_count > 0 THEN --1
            pplog.LOG ( 'POST Api Err.Rule6', 'Total:' || TO_CHAR ( NVL (:NEW.TOTAL_GROSS, 0)));
        -- RAISE_APPLICATION_ERROR (-20004, 'RuleErr(6): Micros Payment(s) cannot user for fiscal invoice.');
        ELSE --1
            pplog.LOG ( '-- l_mpayment_count > 0', :NEW.BILL_NO);
            -- -------------------------------------------------------------------------- --
            IF NVL (:NEW.TOTAL_GROSS, 0) = NVL (:NEW.CASHPAY, 0) + NVL (:NEW.CCPAY, 0) THEN --2
                pplog.LOG ( 'NVL (:NEW.TOTAL_GROSS, 0) = NVL (:NEW.CASHPAY, 0) + NVL (:NEW.CCPAY, 0)', :NEW.BILL_NO);

                -- -------------------------------------------------------------------------- --
                -- Generate content : Populate transaction details
                -- -------------------------------------------------------------------------- --
                SELECT COUNT ( *)
                INTO l_pposting_count
                FROM financial_transactions ft INNER JOIN trx$_codes tc ON tc.resort = ft.resort AND tc.trx_code = ft.trx_code
                WHERE ft.resort = :new.resort AND ft.resv_name_id = :new.resv_name_id AND ft.folio_view = :new.folio_view AND ft.gross_amount > 0 AND NVL (tc.trx_code_type, '@') <> 'X' AND NVL (ft.bill_no, :NEW.BILL_NO) = :NEW.BILL_NO;

                IF l_pposting_count > 0 AND :NEW.TOTAL_GROSS < 0 THEN --3
                    pplog.LOG ( 'POST Api Err.Rule4', 'Total:' || TO_CHAR ( NVL (:NEW.TOTAL_GROSS, 0)));
                    RAISE_APPLICATION_ERROR ( -20004, 'RuleErr(4): You cannot use positive posting in the return invoice.');
                ELSIF TRUNC ( :NEW.TOTAL_GROSS) <> :NEW.TOTAL_GROSS THEN
                    pplog.LOG ( 'POST Api Err.Rule5', 'Total:' || TO_CHAR ( NVL (:NEW.TOTAL_GROSS, 0)));
                    RAISE_APPLICATION_ERROR ( -20004, 'RuleErr(5): The total amount must be an integer. Users must rebate decimal numbers.');
                ELSE
                    pplog.LOG ( 'URL and Context Control', :NEW.BILL_NO);
                    l_url := lf_url;
                    --pplog.LOG ( 'lf_content', lf_content);
                    -- -------------------------------------------------------------------------- --
                    -- 20221208 -- cgurcay : If a fiscal printer not exists it must printed
                    -- -------------------------------------------------------------------------- --
                    IF UPPER ( l_url) LIKE '%HTTP%' THEN --4
                        content := lf_content;
                        pplog.LOG ( 'POST Api Request', content);
                        -- -------------------------------------------------------------------------- --
                        -- 20221216
                        -- -------------------------------------------------------------------------- --
                        l_status_code := send_invoice ( l_url, content);
                        pplog.LOG ( 'l_status_code(1)', l_status_code);
                        IF l_status_code <> 200 THEN
                            pplog.LOG ( 'l_status_code(2)', l_status_code);
                            RAISE_APPLICATION_ERROR ( -20001, 'l_status_code<>200');
                        END IF;
                    -- -------------------------------------------------------------------------- --
                    ELSE -- 4
                        pplog.LOG ( 'Invaid Url ' || NVL (:new.terminal, 'Terminal name not exists'), l_url);
                    END IF; ---4
                -- -------------------------------------------------------------------------- --
                --
                -- -------------------------------------------------------------------------- --

                END IF; ---3
            -- -------------------------------------------------------------------------- --

            ELSIF NVL (:NEW.CASHPAY, 0) + NVL (:NEW.CCPAY, 0) > 0 AND NVL (:NEW.CASHPAY, 0) + NVL (:NEW.CCPAY, 0) <> NVL (:NEW.TOTAL_GROSS, 0) THEN --2
                pplog.LOG ( 'POST Api Err.Rule', 'Cash:' || TO_CHAR ( NVL (:NEW.CASHPAY, 0)) || ' CC:' || TO_CHAR ( NVL (:NEW.CCPAY, 0)) || ' Total:' || TO_CHAR ( NVL (:NEW.TOTAL_GROSS, 0)) || ' Deposit:' || TO_CHAR ( NVL (:NEW.DEPOSIT, 0)));
                RAISE_APPLICATION_ERROR ( -20001, 'RuleErr(3):You cannot use different payment types together');
            END IF; --2
        -- -------------------------------------------------------------------------- --
        --  Rule6
        -- -------------------------------------------------------------------------- --

        END IF; -- 1
    -- -------------------------------------------------------------------------- --

    ELSE
        pplog.LOG ( 'Bill', :NEW.BILL_NO);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        pplog.err ( 'POST Api Err.Other :' || SUBSTR ( UTL_HTTP.GET_DETAILED_SQLERRM, 1, 200));
        RAISE_APPLICATION_ERROR ( -20003, SUBSTR ( UTL_HTTP.GET_DETAILED_SQLERRM, 1, 200));
END ptrg_foliotax_makedon_fiscal;
