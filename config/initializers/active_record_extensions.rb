# frozen_string_literal: true

# See AlphabeticalPaginatorQuery in lib/modules/alphabetical_paginator_query

# extend active record
ActiveRecord::Base.send(:include, AlphabeticalPaginatorQuery)
