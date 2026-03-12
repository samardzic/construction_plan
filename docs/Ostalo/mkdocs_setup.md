# Mkdocs local setup

Mkdocs provides a way to display the current state of the documentation in real time. Therefore a local web server is provided, that watched changes in your local files and updates the website immediately after saving:

### Install mkdocs via pip

```
pip install mkdocs
```

### Install mkdocs additional themes

```
pip install mkdocs-material
pip install mkdocs-bootstrap
pip install mkdocs-windmill
```

### Select themes

Append the following line to your project's ```mkdocs.yml```

```
theme:
  name: 'material'
```

[Additional Themes](http://mkdocs.github.io/mkdocs-bootswatch/#mkdocs-bootstrap-theme)


### Create new project in ROOT folder

```
mkdocs new .
```

### Create new project in sub-folder folder

```
mkdocs new my_project
cd my_project
```


### Execute the serve command in the documentation root folder:

```
mkdocs serve -a 127.0.0.1:9000
```

### Open the webpage in your browser

[127.0.0.1:9000](http:\\127.0.0.1:9000)


### Commands

* `mkdocs new [dir-name]` - Create a new project.
* `mkdocs serve` - Start the live-reloading docs server.
* `mkdocs build` - Build the documentation site.
* `mkdocs help` - Print this help message.


