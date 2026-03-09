# frozen_string_literal: true

class ConvertScriptCommandsToLiquidSyntax < ActiveRecord::Migration[8.0]
  def up
    say_with_time 'Converting scripts.executable_command placeholders to Liquid syntax' do
      execute <<~'SQL'
        UPDATE scripts
        SET executable_command =
          regexp_replace(
            executable_command,
            '(^|[^{])\{([a-zA-Z_][a-zA-Z0-9_]*)\}',
            '\1{{\2}}',
            'g'
          )
        WHERE executable_command IS NOT NULL
          AND executable_command ~ '\{[a-zA-Z_][a-zA-Z0-9_]*\}';
      SQL
    end
  end

  def down
    say_with_time 'Converting scripts.executable_command placeholders from Liquid syntax' do
      execute <<~'SQL'
        UPDATE scripts
        SET executable_command =
          regexp_replace(
            executable_command,
            '\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}',
            '{\1}',
            'g'
          )
        WHERE executable_command IS NOT NULL
          AND executable_command ~ '\{\{\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\}\}';
      SQL
    end
  end
end
