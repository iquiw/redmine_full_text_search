class CreateIssueContents < ActiveRecord::Migration[4.2]
  def change
    reversible do |d|
      d.up do
        case
        when Redmine::Database.postgresql?
          create_table :issue_contents do |t|
            t.integer :project_id
            t.integer :issue_id, unique: true, null: false
            t.string :subject
            t.text :contents
            t.integer :status_id
            t.boolean :is_private
          end
        when Redmine::Database.mysql?
          create_table :issue_contents, options: "ENGINE=Mroonga" do |t|
            t.integer :project_id
            t.integer :issue_id, unique: true, null: false
            t.string :subject
            t.text :contents, limit: 16.megabytes
            t.integer :status_id
            t.boolean :is_private
          end
        end
        load_data
      end
      d.down do
        drop_table :issue_contents
      end
    end
  end

  private

  def load_data
    n_records = Issue.count(:id)
    n_pages = n_records / 1000
    (0..n_pages).each do |offset|
      Issue.eager_load(:journals).limit(1000).offset(offset * 1000).each do |issue|
        contents = [issue.subject, issue.description] + issue.journals.sort_by(&:id).map(&:notes)
        FullTextSearch::IssueContent.create(
          project_id: issue.project_id,
          issue_id: issue.id,
          subject: issue.subject,
          contents: contents.join("\n"),
          status_id: issue.status_id,
          is_private: issue.is_private
        )
      end
    end
  end
end
