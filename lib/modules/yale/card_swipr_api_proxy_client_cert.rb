# Helper code for the application
module Yale
  require 'json'
  require 'singleton'

  # Proxy for CardSwipr API
  # Will be deprecated 7/1/2017 when the API changes to basic auth
  class CardSwiprApiProxy
    include Singleton

    def initialize
      Rails.logger.info('Yale::CardSwiprApiProxy#initialize API URL: ' \
        "#{Rails.configuration.custom.cardSwiprApiURL})")

      @cert = cert
      @key = key
    end

    # Client-side SSL certificate
    def cert
      certfile = Rails.application.secrets.ssl_client_certificate
      Rails.logger.info("CardSwiprApiProxy#get_cert path: #{certfile}")
      OpenSSL::X509::Certificate.new(File.read(certfile))
    rescue
      Rails.logger.fatal("ERROR Failed to load cert file at #{certfile}")
      return nil
    end

    # Client-side SSL private key
    def key
      keyfile = Rails.application.secrets.ssl_client_key
      Rails.logger.info("CardSwiprApiProxy#get_key path: #{keyfile}")
      OpenSSL::PKey::RSA.new(File.read(keyfile))
    rescue
      Rails.logger.fatal("ERROR Failed to load key file at #{keyfile}")
      return nil
    end

    # Send query to Layer7 and return the response.
    def send(query)
      url = "#{Rails.configuration.custom.cardSwiprApiURL}?type=json&#{query}"
      Rails.logger.info("CardSwiprApiProxy#send URL: #{url}")

      rsrc = RestClient::Resource.new(
        url,
        headers: { accept: :json },
        ssl_client_cert: @cert,
        ssl_client_key: @key,
        verify_ssl: OpenSSL::SSL::VERIFY_PEER)

      response = rsrc.get
      Rails.logger.debug("CardSwiprApiProxy#send raw response: #{response}")
      response_obj = JSON.parse(response)
      response_obj['ServiceResponse']['Record']
    rescue RestClient::Exception => e
      Rails.logger.error("CardSwiprApiProxy#send RestClient::Exception #{e}")
      raise CustomError.new(7000 + e.response.code, "Could not find the person")
    rescue => e
      Rails.logger.error("CardSwiprApiProxy#send error: #{e}")
      raise e
    end

    def find_by_upi(upi)
      send("upi=#{upi}")
    end

    def find_by_netid(netid)
      send("netid=#{netid}")
    end

    def find_by_email(email)
      send("email=#{email}")
    end

    def find_by_prox_num(num)
      send("proxNumber=#{num}")
    end

    def find_by_mag_stripe_num(num)
      send("magstripenumber=#{num}")
    end
  end
end
