#!/usr/bin/env python
"""
UDP echo test
"""

import socket
# import urllib2
import urllib.request as urllib2

true_socket = socket.socket  # a socket object being generated
print(true_socket)

def make_bound_socket(source_ip):
    def bound_socket(*a, **k):
        sock = true_socket(*a, **k)
        sock.bind((source_ip, 0))  #just running a method of socket object AL
        return sock
    return bound_socket

# socket.socket = make_bound_socket('<some source ip>')
# print urllib2.urlopen('http://httpbin.org/ip').read()

# socket.socket = make_bound_socket('<some other source ip>')
# print urllib2.urlopen('http://httpbin.org/ip').read()

import inspect
print("true_socket")
print(inspect.getfile(true_socket))  # inspecting where this func came from
# print output:
# <class 'socket.socket'>
# true_socket
# /usr/lib/python3.10/socket.py


if inspect.ismethod(true_socket):
    the_class = true_socket.__self__.__class__
    print("true_socket class is = ", the_class)
    # didnt enter this

print("Printing true_socket module = ",true_socket.__module__)
    # Printing true_socket module =  socket

print("Printing run_simulatitrue_socketon whole path of the file = ", true_socket.__globals__['__file__'])
    # error
    # AttributeError: type object 'socket' has no attribute '__globals__'
