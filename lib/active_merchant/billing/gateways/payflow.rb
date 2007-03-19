require File.dirname(__FILE__) + '/payflow/payflow_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowGateway < Gateway
      include PayflowCommonAPI
      
      def authorize(money, credit_card, options = {})
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
  
        request = build_sale_or_authorization_request('Authorization', money, credit_card, options)
        commit(request)
      end
      
      def purchase(money, credit_card, options = {})
        if result = test_result_from_cc_number(credit_card.number)
          return result
        end
        
        request = build_sale_or_authorization_request('Sale', money, credit_card, options)
        commit(request)
      end                       
      
      def express
        @express ||= PayflowExpressGateway.new(@options)
      end
      
      def self.supported_cardtypes
        [:visa, :master, :american_express, :jcb, :discover, :diners_club]
      end
      
      private      
      def build_sale_or_authorization_request(action, money, credit_card, options)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! action do
          xml.tag! 'PayData' do
            xml.tag! 'Invoice' do
              xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
              xml.tag! 'InvNum', options[:order_id] unless options[:order_id].blank?
              xml.tag! 'Description', options[:description] unless options[:description].blank?

              billing_address = options[:billing_address] || options[:address]
              shipping_address = options[:shipping_address] || billing_address

              add_address(xml, 'BillTo', billing_address, options)
              add_address(xml, 'ShipTo', shipping_address, options)
              
              xml.tag! 'TotalAmt', amount(money), 'Currency' => currency(money)
              
             
            end
            
            xml.tag! 'Tender' do
              add_credit_card(xml, credit_card)
            end
          end 
        end
        xml.target!
      end
      
      def add_credit_card(xml, credit_card)
        xml.tag! 'Card' do
          xml.tag! 'CardType', CARD_MAPPING[credit_card.type.to_sym]
          xml.tag! 'CardNum', credit_card.number
          xml.tag! 'ExpDate', expdate(credit_card)
          xml.tag! 'NameOnCard', credit_card.name
          xml.tag! 'CVNum', credit_card.verification_value if credit_card.verification_value?
          
          if requires_start_date_or_issue_number?(credit_card)
            xml.tag!('ExtData', 'Name' => 'CardStart', 'Value' => startdate(credit_card)) unless credit_card.start_month.blank? || credit_card.start_year.blank?
            xml.tag!('ExtData', 'Name' => 'CardIssue', 'Value' => credit_card.issue_number) unless credit_card.issue_number.blank?
          end
        end
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{year}#{month}"
      end
      
      def startdate(creditcard)
        year  = format(creditcard.start_year, :two_digits)
        month = format(creditcard.start_month, :two_digits)

        "#{month}#{year}"
      end
      
      def build_response(success, message, response, options = {})
        Response.new(success, message, response, options)
      end
    end
  end
end
