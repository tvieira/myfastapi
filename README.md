# Pipenv and S2i: A Better Developer Experience for Python Containers

## Table of Contents

- [Pipenv and S2i: A Better Developer Experience for Python Containers](#pipenv-and-s2i--a-better-developer-experience-for-python-containers)
  * [Table of Contents](#table-of-contents)
  * [Executive Summary](#executive-summary)
  * [The Shortcomings of Pip](#the-shortcomings-of-pip)
  * [Introducing Pipenv, Pipfile, and Pipfile.lock](#introducing-pipenv--pipfile--and-pipfilelock)
  * [S2i vs Dockerfiles](#s2i-vs-dockerfiles)
  * [Building An Example App With Pipenv and S2i](#building-an-example-app-with-pipenv-and-s2i)
    + [Initial Dependencies Install](#initial-dependencies-install)
    + [Creating the Application](#creating-the-application)
    + [Configuring the S2i Build](#configuring-the-s2i-build)
    + [Building And Deploying Our Container On OpenShift](#building-and-deploying-our-container-on-openshift)
      - [Creating the Application From the CLI](#creating-the-application-from-the-cli)
      - [Creating the Application from the Web Console](#creating-the-application-from-the-web-console)
  * [Conclusion](#conclusion)

## Executive Summary

When starting down the path to learning Python and attempting to containerize a Python application, there are a number of challenges developers may face when building and maintaining containerized Python applications.  In this article, we will discuss some of the common problems Python developers may face when containerizing Python applications, and how Pipenv and s2i can help to resolve those problems.  Finally we will build a simple Python application using those tools.

## The Shortcomings of Pip

`pip` is an incredibly simple and powerful tool that enables developers to easily install packages in their environment. That simplicity creates several problems that make it easy for both new and experienced developers to unknowingly introduce problems for themselves later on.

The first challenge developers often face when attempting to containerize their application is understanding exactly what packages they need to install in their container.

The `requirements.txt` file is a common pattern python developers will use for tracking what packages need to be installed in the container.  At first glance, the requirements file appears to solve the problem, simply requiring the execution of `pip install -r requirements.txt` in the container build process.  However, several problems can still occur with a `requirements.txt` file.  

One major issue with the requirements file is with tracking dependencies of dependencies.  A developer may specify package `a` in the requirements file which then installs package `b` automatically.  This may work perfectly today but has potentially introduced a future dependency problem.  Package `a` defines the requirement for `b` as simply `b>=1.0.0` and does not specify an upper limit of the dependency version.  At some point package `b` releases an update which removes a feature that `a` is using and now my application is breaking.  

## Introducing Pipenv, Pipfile, and Pipfile.lock

Pipenv attempts to solve many of these problems. `pipenv` replaces `pip` as the tool developers use to install packages.  Unlike tools like `conda`, `pipenv` installs the same packages available from pypi.org that are available with `pip`.

To get `pipenv` you can install it with `pip install pipenv`.  Once `pipenv` is installed you are ready to start installing additional packages specific to your project.  Where you previously would have run `pip install requests` you can instead run `pipenv install requests` to get the exact same package.  When running `pipenv` in a project for the first time you will immediately see it create a file called `Pipfile`.  The `Pipfile` after install `requests` will look like the following:

*Pipfile:*
```toml
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]
requests = "*"

[dev-packages]

[requires]
python_version = "3.9"
```

Just like the `requirements.txt`, the `Pipfile` is able to capture which packages we wish to install, but `pipenv` is able to automatically maintain the file for us. It also captures some other useful information, such as the Python version we are using. Additionally, it has a section for `dev-packages`.  If you wish to use an automatic code formatter in your project like `black` you can simply run `pipenv install black --dev` to capture the dev requirements separately from the main application requirements.

`pipenv` creates another file called `Pipfile.lock`.  The lock file handles pinning the versions of all of the packages you have installed and their dependencies, similar to running `pip freeze > requirements.txt`.  This allows you to reinstall the exact same version of all components even if newer versions of those packages have come out since last running `pipenv`.  If you need to rebuild your container several months down the line running `pipenv install --deploy` will install the exact package versions specified in the lock file, ensuring that changes in dependencies won't accidentally break your application. `Pipfile` and `Pipfile.lock` are intended to be checked into source control so don't be intimidated by the fact that `Pipfile.lock` is automatically generated.

Another mistake that new Python developers often make is attempting to work from their global user Python environment.  Virtual environments allow you to create a "clean" python environment that you are able to install and manage packages independently from the global Python environment.  Python has a number of tools and methods for creating and managing virtual environments which can be a bit overwhelming.  

Thankfully `pipenv`, like it's name implies, will manage your environment for you.  When running `pipenv install` pipenv will automatically detect if there is already a virtual environment created for this project and either create a new virtual environment or install the packages into the existing virtual environment. That virtual environment can easily be activated with `pipenv shell` allowing you to access and run your application or packages from that virtual environment. 

>Tip: I prefer to keep my virtual environment in my project folder with my `Pipfile` and by default `pipenv` generates it in a centrally located folder.  You can change this behavior by setting the following in your .bashrc file:
>
>`export PIPENV_VENV_IN_PROJECT=1`
>
>With this option set, pipenv will create a `.venv/` folder to manage the virtual environment directly in your project folder.  This folder can easily be deleted if you want to rebuild it from scratch or you just need to cleanup disk space.  `.venv/` is a standard folder naming convention for virtual environments and should already be included on any standard Python `.gitignore` file.

## S2i vs Dockerfiles

S2i (Source to Image) is a tool that enables developers to easily generate a container image from source code without having to write a Dockerfile.  This may sound like a minor task for a seasoned containers expert, but creating an optimized image has a number of "gotchas" that many developers aren't aware of.  Correctly managing layers, properly cleaning up unneeded install artifacts, and running as non-root users are all problems that can lead to a sub-optimal or non-functional image.  To combat this organizations will often maintain "reference" Dockerfiles and tell their developers "go copy this Dockerfile for your Python app and modify it as needed", making for a challenging maintenance task down the road.

S2i instead does away with the Dockerfile and simply ships the instructions for building the image in the image itself.  This does require you have an s2i enabled image for the language you are attempting to build but the good news is nearly all of the language specific images shipped with OpenShift are s2i enabled.

S2i images do expect that you follow some standard conventions for the language in your application structure, but if necessary you can always modify or extend the default `assemble` and `run` scripts.  For Python-s2i, the assemble script expects your application to have a `requirements.txt` file and the run script looks for an `app.py` file.  The assemble script does also have some options can be easily enable for `pipenv` that we will explore later.

>Tip: When dealing with more advanced configuration options in s2i it is always great to reference the source code to see exactly what s2i is running.  You can exec into the container to view the assemble and run scripts directly but most of the time I find it easier to just look it up on GitHub.  The s2i scripts for Python 3.9 can be found here:
>
>https://github.com/sclorg/s2i-python-container/blob/master/3.9/s2i/bin/

## Building An Example App With Pipenv and S2i

To demonstrate the capabilities of pipenv and s2i we will build a simple "Hello World" application with FastAPI based on the [FastAPI First Steps Tutorial](https://fastapi.tiangolo.com/tutorial/first-steps/).

To view the completed application, please find the source code [here](https://github.com/strangiato/pipenv-s2i-example).

### Initial Dependencies Install

To begin we can create a new `Pipfile` and virtual environment with fastapi by running the following:

```sh
pipenv install fastapi
```

As discussed previously, pipenv will create the `Pipfile`, `Pipfile.lock` and a virtual environment with fastapi installed in it.  To verify that we can activate the virtual environment and list the packages with the following:

```sh
pipenv shell
pip list
```

The output should show fastapi and fastapi's dependencies.

While still in our shell we can continue to install additional packages such as `black`.  Since `black` is only needed in our development environment and not in the production application, we will use the `--dev` flag:

```sh
pipenv install black --dev
```

### Creating the Application

Next we will create the FastAPI example application based on the first-steps tutorial.

*hello_world/main.py:*
```python
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Hello World"}
```

Additionally, it is always a best practice to create an empty file called `__init__.py` in our source code folder (hello_world).

At this point your application is ready to start in your local environment.  You can run the following command with your virtual environment still active to start the application:

```sh
uvicorn hello_world.main:app
```

I have chosen to put the application file in a subfolder inside of my git repo instead of creating it in the root of the project.  While we don't have much in the `hello_world` folder, most real applications will have additional files and folders.  By starting with the application in the subfolder we are able to keep the root of the project relatively clean and readable but it also creates some flexibility for our application later on.

Our application is now functioning and we are ready to consider how we will containerize it.  The first question we need to answer is how will our application start.  As mentioned before, Python-s2i looks for an `app.py` file in the root of the project and attempts to use that to start the application.  If you browse the Python-s2i run script though you may also notice that it supports starting the application from `app.sh` if an `app.py` file isn't found.  One option is to include our uvicorn command above in the `app.sh` file but I prefer to try and keep everything as Python.  Instead we can start our application with the following:

*app.py:*
```python
from hello_world.main import app

import uvicorn


if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
    )
```

To test this again we can run the following:

```sh
python app.py
```

This time we encounter an error since we are missing the uvicorn package:

```
Traceback (most recent call last):
  File "/home/troyer/code/pipenv-tutorial/app.py", line 3, in <module>
    import uvicorn
ModuleNotFoundError: No module named 'uvicorn'
```

To resolve this we can simply add the package with pipenv:

```sh
pipenv install uvicorn
```

Pipenv will capture the new dependency in the `Pipfile` and `Pipfile.lock`, giving us no additional work to manually capture the requirement.

Running `app.py` again should now function correctly.

### Configuring the S2i Build

Next we need to consider how our application will build.  As mentioned before, Python-s2i looks for the `requirements.txt` file by default, but it does support other build options.  If you explore the [assemble](https://github.com/sclorg/s2i-python-container/blob/master/3.9/s2i/bin/assemble) script you will find references to two different environment variables that we can utilize, `ENABLE_PIPENV` and `ENABLE_MICROPIPENV`.

`ENABLE_PIPENV` allows the assemble script to install packages from `Pipfile.lock` using the standard `pipenv` package.  `ENABLE_MICROPIPENV` will also allow us to install packages from our `Pipfile.lock` but instead utilizes a tool called [micropipenv](https://github.com/thoth-station/micropipenv) from thoth-station, an open source group sponsored by Red Hat.  Micropipenv has a few advantages including that it is smaller then `pipenv`, optimized for installing packages in containers, and incredibly fast.  It also has the added benefit that it also supports Poetry, another popular alternative dependency manager to `pip` and `pipenv`.

To enable either option we can set the environment variable later on in our BuildConfig or we can do it directly in our git repo with a `.s2i/environment` file:

*.s2i/environment:*
```sh
ENABLE_MICROPIPENV=True
```

Finally, the last thing we need to consider is which files are included in our application.  By default s2i will do the docker equivalent of `COPY . .` which copies everything in our git repo into the container.  Our example application doesn't have a whole lot extra in it now but we may accidentally introduce unwanted artifacts in our container.  For example if we later add a `tests/` folder, we don't want to include our tests in our container.  To manage what gets added to the final container we can utilize a `.s2iignore` file.  This file semantically functions exactly the same as `.gitignore` but determines what is ignored when copying the contents of our repo to the container.

While most `.gitignore` files list the files we don't want to include in our git repo, I generally prefer to start by excluding all files in my `.s2iignore` and then explicitly add the ones I do need back.  This helps to prevent any extra files accidentally slipping through later on and keeps our container size to a minimum.

*.s2iignore:*
```sh
# Ignore everything
*

# Allow specific files
!.s2iignore
!.s2i/
!hello_world/
!LICENSE
!Pipfile
!Pipfile.lock
!app.py
```

The last step before we are ready to build our application with OpenShift is to push any code to GitHub.

### Building And Deploying Our Container On OpenShift

For the final step of building and deploying our container on OpenShift we have the ability to create the necessary artifacts from the command line with `oc new-app` or through the UI using the `+Add` interface.

#### Creating the Application From the CLI

To create our application from the command line you can run the following command.  Be sure that you have set your project with `oc project` prior to running the `new-app` command.


```sh
oc new-app openshift/python:3.9-ubi8~https://github.com/strangiato/pipenv-s2i-example.git --name hello-world
```

In OpenShift a new application should appear, a build should run relatively quickly, and the application should start successfully.

In order to test our application we can create a route with the following command:

```sh
oc expose svc/hello-world
```

We should now be able to access our API endpoint via the route and see our "Hello World' message.

#### Creating the Application from the Web Console

To perform the same actions from the UI you can navigate to the `+Add` menu in the `Developer` view.  Next, select `Import from Git` and copy the git URL into the `Git Repo URL` field.  Next, click `Edit Import Strategy`, select `Python` and make sure a 3.9 image is automatically selected.  Update any of the object names and click `Create`.

Just like with `oc new-app` a new Build should kick off and the application will deploy successfully.  Since the UI defaults to creating a route, you should be able to access the API endpoint right away.

## Conclusion

In this article we discussed some of the common problems Python developers encounter when attempting to containerize applications and how we can solve some of those problems with `pipenv` and s2i.  Additionally, we created a simple web application using pipenv and Python-s2i on OpenShift.
