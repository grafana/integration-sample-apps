# /scripts/render_template.py
import yaml
import jinja2
import os

def render_templates(config_file, template_dir, output_dir):
    # Load configuration
    with open(config_file) as file:
        config = yaml.safe_load(file)

    # Set up Jinja2 environment
    template_loader = jinja2.FileSystemLoader(searchpath=template_dir)
    template_env = jinja2.Environment(loader=template_loader)
    
    # Render templates
    for template_file in template_env.list_templates():
        template = template_env.get_template(template_file)
        output = template.render(config)

        # Write output to file
        output_file_path = os.path.join(output_dir, template_file.replace('.j2', ''))
        with open(output_file_path, "w") as f:
            f.write(output)
        print(f"Generated: {output_file_path}")

# Define file paths
config_file = "jinja/variables/cloud-init.yaml"
template_dir = "jinja/templates"
output_dir = "generated_configs"  # Output directory for rendered files

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

# Run the rendering process
render_templates(config_file, template_dir, output_dir)

