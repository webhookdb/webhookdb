# frozen_string_literal: true

require "aws-sdk-pricing"

require "webhookdb/aws"
require "webhookdb/replicator/base"

class Webhookdb::Replicator::AwsPricingV1 < Webhookdb::Replicator::Base
  include Webhookdb::DBAdapter::ColumnTypes

  CURRENCIES = ["USD", "CNY"].freeze

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "aws_pricing_v1",
      ctor: self,
      resource_name_singular: "AWS Price List",
      feature_roles: ["beta"],
    )
  end

  def _denormalized_columns
    return [
      # Product
      Webhookdb::Replicator::Column.new(:product_sku, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:product_family, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:product_attributes, OBJECT),
      Webhookdb::Replicator::Column.new(:product_group, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:product_location, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:product_region, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:product_operation, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:product_usagetype, TEXT, index: true),

      Webhookdb::Replicator::Column.new(:publication_date, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:service_code, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:version, TEXT, index: true),

      # Term (OnDemand, etc)
      Webhookdb::Replicator::Column.new(:term_type, TEXT),
      Webhookdb::Replicator::Column.new(:term_code, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:offer_term_code, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:effective_date, TIMESTAMP, index: true),

      # Term fields
      # Webhookdb::Replicator::Column.new(:rate_code, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:applies_to, TEXT_ARRAY),
      Webhookdb::Replicator::Column.new(:begin_range, DECIMAL),
      Webhookdb::Replicator::Column.new(:description, TEXT),
      Webhookdb::Replicator::Column.new(:end_range, DECIMAL),
      Webhookdb::Replicator::Column.new(:unit, TEXT),
      Webhookdb::Replicator::Column.new(:term_attributes, OBJECT),

      Webhookdb::Replicator::Column.new(:price_per_unit_raw, OBJECT),
      Webhookdb::Replicator::Column.new(:price_per_unit_amount, DECIMAL),
      Webhookdb::Replicator::Column.new(:price_per_unit_currency, TEXT),
    ]
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:rate_code, TEXT)
  end

  def _timestamp_column_name
    return :publication_date
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _resource_to_data(_resource, _event, _request)
    return {}
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:publication_date] < Sequel[:excluded][:publication_date]
  end

  def _webhook_response(_request)
    # There are no webhooks to respond to, these are backfill-only integrations
    return Webhookdb::WebhookResponse.ok
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_create_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.backfill_key.blank?
      step.output = %(In order to populate AWS prices, you'll need to allow WebhookDB
to access the Pricing service in your account. We use 3rd party roles for this.
(Note: self-hosted WebhookDB customers have other auth methods available).

Here's how to do this from the AWS Console; you can do this via CDK or similar if you wish, too.

- Log into AWS
- Go to IAM
- Go to 'Policies' on the nav bar
- Create a policy like this (name it whatever you want, we'll use "WebhookDBPricing"):

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "WebhookDBPricing",
            "Effect": "Allow",
            "Action": [
                "pricing:DescribeServices",
                "pricing:ListPriceLists",
                "pricing:GetAttributeValues",
                "pricing:GetPriceListFileUrl",
                "pricing:GetProducts"
            ],
            "Resource": "*"
        }
    ]
}

- Go to 'Roles' in the nav bar.
- Choose 'AWS Account' as the entity type.
- Choose 'Another AWS Account' and enter our Account ID: #{Webhookdb::AWS.external_account_id}
- Check 'Require an external ID'. Choose whatever you wish. Here's one to try: WHDBPR-#{SecureRandom.hex(8)}
- Go to the next page. Choose the policy created earlier (WebhookDBPricing).
- Go to the next page. Give the role a name like 'WebhookDBPricing'.
- Create the role.
- Find the newly created role, and copy the ARN and External ID.
)
      return step.prompting("Role ARN").backfill_key(self.service_integration)
    elsif self.service_integration.backfill_secret.blank?
      return step.prompting("External ID", secret: true).backfill_secret(self.service_integration)
    end
    step.output = %(Your AWS pricing database will be filled shortly.
It normally takes about 20 minutes to sync.

#{self._query_help_output})
    return step.completed
  end

  # @return [Webhookdb::Replicator::StateMachineStep]
  def calculate_backfill_state_machine
    return self.calculate_create_state_machine
  end

  def _parallel_backfill = 3

  def _backfillers
    pricing = self.create_pricing_client
    backfillers = []
    effective_date = Time.now.iso8601
    # backfillers << ServiceBackfiller.new(self, 'AmazonEC2', 'USD', effective_date)
    pricing.describe_services.each do |services_resp|
      services_resp.services.map do |srv|
        CURRENCIES.each do |currency_code|
          backfillers << ServiceBackfiller.new(self, srv.service_code, currency_code, effective_date)
        end
      end
    end
    return backfillers
  end

  def with_pricing_client
    raise LocalJumpError unless block_given?
    @pricing_client ||= self.create_pricing_client
    begin
      return yield(@pricing_client)
    rescue StandardError => e
      raise e unless e.to_s.include?("The security token included in the request is invalid")
      @pricing_client = self.create_pricing_client
      return yield(@pricing_client)
    end
  end

  def create_pricing_client
    role_arn = self.service_integration.backfill_key
    external_id = self.service_integration.backfill_secret
    assume_resp = Webhookdb::AWS.sts_client.assume_role(
      role_arn:,
      external_id:,
      role_session_name: "webhoookdb_aws_pricing_v1",
    )
    return Aws::Pricing::Client.new(
      session_token: assume_resp.credentials.session_token,
      region: "us-east-1",
      # Lots of extra retries. It's almost always going to be because throttling.
      retry_base_delay: 5,
      retry_limit: 10,
    )
  end

  class ServiceBackfiller < Webhookdb::Backfiller
    include Webhookdb::Backfiller::Bulk

    attr_reader :replicator
    attr_reader :pricing, :service_code, :currency_code, :effective_date

    def initialize(replicator, service_code, currency_code, effective_date)
      @replicator = replicator
      @service_code = service_code
      @currency_code = currency_code
      @effective_date = effective_date
      super()
    end

    def upsert_page_size = 500
    def prepare_body(_body) = nil
    def upserting_replicator = @replicator

    def fetch_backfill_page(pagination_token, **)
      # Fetch a page of price lists ARNs for this service
      list_req = self.replicator.with_pricing_client do |pricing|
        pricing.build_request(
          :list_price_lists,
          {
            currency_code:,
            effective_date:,
            max_results: 100,
            next_token: pagination_token,
            service_code:,
          },
        )
      end
      arns_to_fetch = []
      list_req.send_request({}).each do |list_resp|
        # We need to enumerate everything at once. Because inserting can take so long
        # that next_tokene xpires.
        list_resp.price_lists.map do |pl|
          arns_to_fetch << pl.price_list_arn
        end
      end

      # To avoid having to process the entire JSON file into an array of thousands of items,
      # process rates one-by-one. We may have huge memory for the JSON file itself, but won't need it
      # to store the hashes we'll them bulk insert. This is also more responsive because we'll be upserting
      # pages as we have them available, rather than only after everything is converted.
      iter = UrlStreamer.new(self.replicator, arns_to_fetch)
      # next_token is nil when we have processed all price list files for the service.
      return iter, nil
    end

    class UrlStreamer
      def initialize(replicator, arns)
        @arns = arns
        @replicator = replicator
      end

      def each
        @arns.each do |price_list_arn|
          url_req = @replicator.with_pricing_client do |client|
            client.build_request(
              :get_price_list_file_url,
              {file_format: "json", price_list_arn:},
            )
          end
          url_resp = url_req.send_request({})
          tmp = Tempfile.new("awspricing", binmode: true)
          # This file can be enormous- 200+ mb of JSON. We CANNOT just parse this directly.
          # Even loading it is too much. We write it directly to a file, then process the file.
          # This is a confusing algorithm. Instead of treating it like JSON, we treat it
          # sort of like a text format:
          # - look for known keys at the start of the file
          # - once we hit 'products', we start collecting lines.
          # - once we hit 'terms', we parse 'products', then keep going for terms.
          # - each /^    "/ is a term type, like 'OnDemand' or 'Reserved'
          # - each /^      "/ is a product id and the start of its rates
          # - Grab the lines until /^      }/ and process it as the product rates.
          #   Grab the product from the line offsets.
          Webhookdb::Http.get(url_resp.url, logger: @replicator.logger, stream_body: true) do |fragment|
            tmp.write(fragment)
          end
          tmp.flush
          tmp.seek(0)
          flines = File.foreach(tmp.path)
          # Grab the first section of the file up to 'products', this is the metadata.
          meta_str = +""
          until (mline = flines.next) =~ /^ {2}"products"/
            meta_str << mline
          end
          meta_str << '"":""}'
          meta = Oj.load(meta_str)
          meta_str.clear
          publication_date = Time.parse(meta.fetch("publicationDate"))
          service_code = meta.fetch("offerCode")
          version = meta.fetch("version")

          # Grab all the products. This is like 170k of 5million, so is small enough for memory.
          products_str = +"{"
          until (pline = flines.next) =~ /^ {2}}/
            products_str << pline
          end
          products_str << "}"
          products = Oj.load(products_str)
          products_str.clear

          # Read the rest of the file.
          _terms = flines.next
          term_type = nil
          until (line = flines.next) == "}" # next has EOF problems and end the program/iterator
            # Look for 'OnDemand', 'Reserved', etc.
            start_of_term_type = line =~ /^ {4}"/
            if start_of_term_type
              term_type = line[/^ {4}"([A-Za-z0-9]+)"/, 1]
              next
            end
            start_of_product_and_term_map = line =~ /^ {6}"/
            next unless start_of_product_and_term_map
            # Look for the product SKU, which then lists all the terms (and rates).
            # 'ABC': {'ABC.DEF': {}, 'ABC.XYZ': {}}
            # Parse this entire set of product terms at once- it may be a few thousand lines,
            # which is probably faster anyway than trying to split it up.
            product_sku = line[/^ {6}"([A-Za-z0-9]+)"/, 1]
            term_map_str = +"{"
            until (tline = flines.next) =~ /^ {6}}/
              term_map_str << tline
            end
            term_map_str << "}"
            term_map = Oj.load(term_map_str)
            term_map_str.clear
            product = products.fetch(product_sku)
            product_family = product.fetch("productFamily", nil)
            product_attributes = product.fetch("attributes", {})
            product_group = product_attributes.fetch("group", nil)
            product_location = product_attributes.fetch("location", nil)
            product_region = Webhookdb::AWS::LOCATIONS_TO_REGIONS.fetch(product_location, product_location)
            product_operation = product_attributes.fetch("operation", nil)
            product_usagetype = product_attributes.fetch("usagetype", nil)
            term_map.each do |term_code, term|
              term["priceDimensions"].each do |rate_code, rate|
                price_per_unit_currency, price_per_unit_amount = rate.fetch("pricePerUnit").first
                rate = {
                  product_sku:,
                  product_family:,
                  product_attributes:,
                  product_group:,
                  product_location:,
                  product_region:,
                  product_operation:,
                  product_usagetype:,
                  publication_date:,
                  service_code:,
                  version:,
                  term_type:,
                  term_code:,
                  offer_term_code: term.fetch("offerTermCode"),
                  effective_date: Time.parse(term.fetch("effectiveDate")),
                  term_attributes: term.fetch("termAttributes", {}),
                  rate_code:,
                  applies_to: (applies_to = rate.fetch("appliesTo")) ? Sequel.pg_array(applies_to) : nil,
                  begin_range: self.parse_range(rate.fetch("beginRange", nil)),
                  description: rate.fetch("description"),
                  end_range: self.parse_range(rate.fetch("endRange", nil)),
                  unit: rate.fetch("unit", nil),
                  price_per_unit_raw: rate.fetch("pricePerUnit"),
                  price_per_unit_amount:,
                  price_per_unit_currency:,
                }.stringify_keys
                yield rate
              end
            end
          end
          tmp.unlink
        end
      end

      def parse_range(value)
        return nil if value.nil?
        return nil if value == "Inf"
        return BigDecimal(value)
      end
    end
  end
end

# We depend on these beta price list API calls that aren't yet in the SDK.
# Once they are in the SDK we should remove this code.
unless Aws::Pricing::ClientApi::API.operation_names.include?(:list_price_lists)

  # rubocop:disable Style/StructInheritance:
  module ::Aws::Pricing::Types
    class ListPriceListsRequest < Struct.new(
      :currency_code,
      :effective_date,
      :max_results,
      :next_token,
      :region_code,
      :service_code,
    )
      SENSITIVE = [].freeze
      include Aws::Structure
    end

    class ListPriceListsResponse < Struct.new(
      :next_token,
      :price_lists,
    )
      SENSITIVE = [].freeze
      include Aws::Structure
    end

    class PriceList < Struct.new(
      :price_list_arn,
    )
      SENSITIVE = [].freeze
      include Aws::Structure
    end

    class GetPriceListFileUrlRequest < Struct.new(
      :file_format,
      :price_list_arn,
    )
      SENSITIVE = [].freeze
      include Aws::Structure
    end

    class GetPriceListFileUrlResponse < Struct.new(
      :url,
    )
      SENSITIVE = [].freeze
      include Aws::Structure
    end
  end
  # rubocop:enable Style/StructInheritance

  # rubocop:disable Layout/LineLength
  module ::Aws::Pricing::ClientApi
    ListPriceListsRequest = Shapes::StructureShape.new(name: "ListPriceListsRequest")
    ListPriceListsResponse = Shapes::StructureShape.new(name: "ListPriceListsResponse")
    EffectiveDate = Shapes::TimestampShape.new(name: "EffectiveDate")
    PriceLists = Shapes::ListShape.new(name: "PriceLists")
    PriceList = Shapes::StructureShape.new(name: "PriceList")

    ListPriceListsRequest.add_member(:currency_code, Shapes::ShapeRef.new(shape: String, location_name: "CurrencyCode"))
    ListPriceListsRequest.add_member(:service_code, Shapes::ShapeRef.new(shape: String, location_name: "ServiceCode"))
    ListPriceListsRequest.add_member(:effective_date, Shapes::ShapeRef.new(shape: EffectiveDate, location_name: "EffectiveDate"))
    ListPriceListsRequest.add_member(:next_token, Shapes::ShapeRef.new(shape: String, location_name: "NextToken"))
    ListPriceListsRequest.add_member(:max_results, Shapes::ShapeRef.new(shape: BoxedInteger, location_name: "MaxResults", metadata: {"box" => true}))
    ListPriceListsRequest.add_member(:region_code, Shapes::ShapeRef.new(shape: String, location_name: "RegionCode"))
    ListPriceListsRequest.struct_class = Aws::Pricing::Types::ListPriceListsRequest

    PriceList.add_member(:price_list_arn, Shapes::ShapeRef.new(shape: String, location_name: "PriceListArn"))
    PriceList.struct_class = Aws::Pricing::Types::PriceList

    PriceLists.member = Shapes::ShapeRef.new(shape: PriceList)

    ListPriceListsResponse.add_member(:price_lists, Shapes::ShapeRef.new(shape: PriceLists, location_name: "PriceLists"))
    ListPriceListsResponse.add_member(:next_token, Shapes::ShapeRef.new(shape: String, location_name: "NextToken"))
    ListPriceListsResponse.struct_class = Aws::Pricing::Types::ListPriceListsResponse

    API.add_operation(:list_price_lists, Seahorse::Model::Operation.new.tap do |o|
      o.name = "ListPriceLists"
      o.http_method = "POST"
      o.http_request_uri = "/"
      o.input = Shapes::ShapeRef.new(shape: ListPriceListsRequest)
      o.output = Shapes::ShapeRef.new(shape: ListPriceListsResponse)
      o.errors << Shapes::ShapeRef.new(shape: InternalErrorException)
      o.errors << Shapes::ShapeRef.new(shape: InvalidParameterException)
      o.errors << Shapes::ShapeRef.new(shape: NotFoundException)
      o.errors << Shapes::ShapeRef.new(shape: InvalidNextTokenException)
      o.errors << Shapes::ShapeRef.new(shape: ExpiredNextTokenException)
      o[:pager] = Aws::Pager.new(
        limit_key: "max_results",
        tokens: {
          "next_token" => "next_token",
        },
      )
    end,)

    GetPriceListFileUrlRequest = Shapes::StructureShape.new(name: "GetPriceListFileUrlRequest")
    GetPriceListFileUrlResponse = Shapes::StructureShape.new(name: "GetPriceListFileUrlResponse")

    GetPriceListFileUrlRequest.add_member(:file_format, Shapes::ShapeRef.new(shape: String, location_name: "FileFormat"))
    GetPriceListFileUrlRequest.add_member(:price_list_arn, Shapes::ShapeRef.new(shape: String, location_name: "PriceListArn"))
    GetPriceListFileUrlRequest.struct_class = Aws::Pricing::Types::GetPriceListFileUrlRequest

    GetPriceListFileUrlResponse.add_member(:url, Shapes::ShapeRef.new(shape: String, location_name: "Url"))
    GetPriceListFileUrlResponse.struct_class = Aws::Pricing::Types::GetPriceListFileUrlResponse

    API.add_operation(:get_price_list_file_url, Seahorse::Model::Operation.new.tap do |o|
      o.name = "GetPriceListFileUrl"
      o.http_method = "POST"
      o.http_request_uri = "/"
      o.input = Shapes::ShapeRef.new(shape: GetPriceListFileUrlRequest)
      o.output = Shapes::ShapeRef.new(shape: GetPriceListFileUrlResponse)
      o.errors << Shapes::ShapeRef.new(shape: InternalErrorException)
      o.errors << Shapes::ShapeRef.new(shape: InvalidParameterException)
      o.errors << Shapes::ShapeRef.new(shape: NotFoundException)
    end,)
  end
  # rubocop:enable Layout/LineLength
end
